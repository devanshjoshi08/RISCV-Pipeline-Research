#!/usr/bin/env python3
"""Re-fit the first-principles CPI model and regenerate the three paper figures.

This script is the source of record for the CPI-model statistics reported in
Section IV-E (per-workload R-squared, variance inflation factors, design-matrix
condition number) and for Figures 1-3. All inputs are the final measured values
from Tables II, III, and V of the paper; nothing here is synthetic.
"""

import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

FIG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "paper", "figures")
os.makedirs(FIG_DIR, exist_ok=True)

DEPTHS = np.array([4, 5, 6, 7, 8])
P = np.array([2, 2, 3, 4, 4], dtype=float)      # flush penalty, cycles
L = np.array([0, 1, 1, 1, 1.5])                 # load-use stall, cycles
B = np.array([0, 0, 0, 1, 1], dtype=float)      # IF2 bubble indicator

# workload: instructions, branch frequency, misprediction count per depth, exact cycles per depth.
# Cycles are exact XSim counts (D:/RISCV-Vivado logs; 7s/8s from the bugfixed-RTL rerun);
# CPI is computed at full precision as cycles/instructions, not the 2-decimal table value.
WL = {
    "Dhrystone":  dict(N=2926,    fb=0.137, mis=[203, 203, 203, 203, 203],
                       cyc=[4134, 4334, 4938, 5440, 5840]),
    "Diagnostic": dict(N=1367,    fb=0.263, mis=[69, 69, 69, 69, 69],
                       cyc=[1887, 2187, 2267, 2579, 2889]),
    "CoreMark":   dict(N=2893145, fb=0.249, mis=[145735, 145735, 154077, 147760, 147760],
                       cyc=[4481534, 4724937, 5310372, 5856929, 6323069]),
    "aha-mont64": dict(N=4453858, fb=0.115, mis=[140683, 140683, 139739, 139739, 139739],
                       cyc=[5417748, 5427188, 5606583, 5905364, 5917639]),
    "crc32":      dict(N=4008648, fb=0.044, mis=[344]*5,
                       cyc=[5229778, 5229778, 5578969, 6102235, 6276316]),
    "statemate":  dict(N=3160225, fb=0.119, mis=[66603, 66603, 69933, 73263, 73263],
                       cyc=[3842893, 4125943, 4335743, 4742011, 5371382]),
    "edn":        dict(N=2972527, fb=0.114, mis=[10452]*5,
                       cyc=[4426900, 4491135, 4961349, 5300503, 5823604]),
}
for _w in WL.values():
    _w["cpi"] = [c / _w["N"] for c in _w["cyc"]]
ORDER = list(WL.keys())

# Build the design matrix for CPI - 1 - (M/N)*P = alpha*L + beta*(B*fb) + sum_w gamma_w * 1[w]
rows, y, wl_idx = [], [], []
for wi, w in enumerate(ORDER):
    d = WL[w]
    mr = np.array(d["mis"], dtype=float) / d["N"]      # mispredictions per instruction
    branch_flush = mr * P
    resp = np.array(d["cpi"]) - 1.0 - branch_flush
    for k in range(5):
        ind = [0.0] * len(ORDER)
        ind[wi] = 1.0
        rows.append([L[k], B[k] * d["fb"]] + ind)
        y.append(resp[k])
        wl_idx.append(wi)
X = np.array(rows)
y = np.array(y)
wl_idx = np.array(wl_idx)

beta, *_ = np.linalg.lstsq(X, y, rcond=None)
alpha, beta_if2 = beta[0], beta[1]
gammas = dict(zip(ORDER, beta[2:]))

# Reconstruct full predicted CPI for every observation
pred = np.empty(35)
meas = np.empty(35)
i = 0
for w in ORDER:
    d = WL[w]
    mr = np.array(d["mis"], dtype=float) / d["N"]
    for k in range(5):
        pred[i] = 1.0 + mr[k] * P[k] + alpha * L[k] + beta_if2 * B[k] * d["fb"] + gammas[w]
        meas[i] = d["cpi"][k]
        i += 1
resid = meas - pred

def r2(ym, yp):
    ss_res = np.sum((ym - yp) ** 2)
    ss_tot = np.sum((ym - np.mean(ym)) ** 2)
    return 1.0 - ss_res / ss_tot if ss_tot > 0 else float("nan")

R2 = r2(meas, pred)
n, p = 35, 2 + len(ORDER)
R2_adj = 1 - (1 - R2) * (n - 1) / (n - p)
mae = np.mean(np.abs(resid))
maxres = resid[np.argmax(np.abs(resid))]

print("=== Global fit ===")
print(f"alpha (load-use)      = {alpha:.3f}")
print(f"beta  (IF2 bubble)    = {beta_if2:.3f}")
print(f"R^2 = {R2:.3f}   R^2_adj = {R2_adj:.3f}   MAE = {mae:.3f}   max resid = {maxres:+.3f}")

print("\n=== Per-workload R^2 (M5a) ===")
for wi, w in enumerate(ORDER):
    m = wl_idx == wi
    print(f"  {w:12s} R^2 = {r2(meas[m], pred[m]):.3f}   gamma_w = {gammas[w]:+.3f}")

# Largest |residual| obs (for figure annotation)
j = np.argmax(np.abs(resid))
print(f"\nLargest residual: {ORDER[wl_idx[j]]} depth {DEPTHS[j%5]}  resid = {resid[j]:+.3f}")

# --- M5c: VIF and condition number for the depth-dependent regressors -----------
# VIF_k = 1 / (1 - R^2_k) where R^2_k regresses regressor k on the others.
def vif(M):
    out = []
    for k in range(M.shape[1]):
        others = np.delete(M, k, axis=1)
        coef, *_ = np.linalg.lstsq(others, M[:, k], rcond=None)
        r2k = r2(M[:, k], others @ coef)
        out.append(1.0 / (1.0 - r2k) if r2k < 1 else float("inf"))
    return out

vifs = vif(X)
# Condition number of the depth-dependent design block [L, B*fb] together with a
# constant column (the per-workload intercepts collapse to one shared constant for
# this purpose). This is the block whose conditioning the reviewer asks about.
Xdep = np.column_stack([np.ones(35), X[:, 0], X[:, 1]])
cond = np.linalg.cond(Xdep)
print("\n=== Collinearity (M5c) ===")
print(f"VIF(alpha,L)      = {vifs[0]:.2f}")
print(f"VIF(beta,B*fb)    = {vifs[1]:.2f}")
print(f"condition number [1, L, B*fb] = {cond:.2f}")

# ============================ FIGURES ==========================================
plt.rcParams.update({
    "font.size": 10, "axes.labelsize": 11, "axes.titlesize": 11,
    "xtick.labelsize": 9, "ytick.labelsize": 9, "legend.fontsize": 8,
    "savefig.bbox": "tight", "savefig.pad_inches": 0.05,
    "pdf.fonttype": 42, "ps.fonttype": 42,
})
COLORS = ["#2196F3", "#4CAF50", "#FF9800", "#E91E63", "#9C27B0"]
LAB = ["4-stg", "5-stg", "6-stg", "7-stg", "8-stg"]

# Fig 1: Fmax with error bars (final 10-seed data)
fmax_mean = [70.4, 74.0, 117.3, 115.0, 117.5]
fmax_std  = [2.4, 1.5, 1.4, 2.0, 1.8]
fig, ax = plt.subplots(figsize=(3.4, 2.6))
x = np.arange(5)
ax.bar(x, fmax_mean, yerr=fmax_std, capsize=4, color=COLORS,
       edgecolor="black", linewidth=0.5)
ax.set_xticks(x); ax.set_xticklabels(LAB)
ax.set_ylabel(r"$F_{\max}$ (MHz)")
ax.set_ylim(0, 135)
for xi, m, s in zip(x, fmax_mean, fmax_std):
    ax.text(xi, m + s + 1.5, f"{m:.1f}", ha="center", va="bottom",
            fontsize=8, fontweight="bold")
plt.savefig(os.path.join(FIG_DIR, "fmax_comparison.pdf"))
plt.close()

# Fig 2: misprediction rate vs depth, CoreMark + statemate (deterministic, no error bars)
cm_rate = [145735, 145735, 154077, 147760, 147760]
cm_rate = [100.0 * v / 719810 for v in cm_rate]
sm_rate = [66603, 66603, 69933, 73263, 73263]
sm_rate = [100.0 * v / 376291 for v in sm_rate]
fig, ax = plt.subplots(figsize=(3.4, 2.6))
ax.plot(DEPTHS, cm_rate, "o-", color="#2196F3", label="CoreMark")
ax.plot(DEPTHS, sm_rate, "s--", color="#FF9800", label="statemate")
ax.set_xlabel("Pipeline depth (stages)")
ax.set_ylabel("Misprediction rate (%)")
ax.set_xticks(DEPTHS)
ax.grid(True, alpha=0.3)
ax.legend()
plt.savefig(os.path.join(FIG_DIR, "mispred_comparison.pdf"))
plt.close()

# Fig 3: measured vs predicted CPI, all 35 points, with residual annotation
fig, ax = plt.subplots(figsize=(3.4, 2.8))
ax.plot([1.1, 2.25], [1.1, 2.25], color="black", linewidth=0.6,
        linestyle="--", zorder=1)
for wi, w in enumerate(ORDER):
    m = wl_idx == wi
    ax.scatter(pred[m], meas[m], s=22, color=COLORS[wi % 5], zorder=3,
               label=w if wi < 7 else None)
# annotate the largest-magnitude residual
_lab = f"{ORDER[wl_idx[j]]} {DEPTHS[j % 5]}-stg"
ax.annotate(f"{_lab}\nresid {resid[j]:+.3f}",
            xy=(pred[j], meas[j]), xytext=(pred[j] - 0.05, meas[j] + 0.18),
            fontsize=7, ha="right",
            arrowprops=dict(arrowstyle="->", lw=0.6))
ax.set_xlabel("Predicted CPI (cycles/instr)")
ax.set_ylabel("Measured CPI (cycles/instr)")
ax.text(1.13, 2.12, fr"$R^2={R2:.3f}$", fontsize=8)
ax.legend(fontsize=6, loc="lower right", ncol=2)
ax.grid(True, alpha=0.3)
plt.savefig(os.path.join(FIG_DIR, "cpi_vs_depth.pdf"))
plt.close()

print("\nFigures written:", os.path.join(FIG_DIR, "{fmax_comparison,mispred_comparison,cpi_vs_depth}.pdf"))
