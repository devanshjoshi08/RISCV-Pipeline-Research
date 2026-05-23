#!/usr/bin/env python3
"""Regenerate throughput_comparison and published_cores_comparison with
Fmax consistent with tab:results (10-seed means) and CPI from the benchmark
tables. Throughput in IEEE serif style; MIPS computed = Fmax/CPI."""
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIG_DIR = os.path.join(BASE, "paper", "figures")

plt.rcParams.update({
    "font.family": "serif",
    "font.serif": ["Times New Roman", "DejaVu Serif", "serif"],
    "font.size": 10, "axes.labelsize": 11, "axes.titlesize": 12,
    "axes.titleweight": "bold", "xtick.labelsize": 9, "ytick.labelsize": 9,
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.alpha": 0.3, "grid.linestyle": "--",
    "figure.dpi": 200, "savefig.bbox": "tight", "savefig.pad_inches": 0.12,
})

LABELS = ["4-stage", "5-stage", "6-stage", "7-stage", "8-stage"]
fmax     = [70.4, 74.0, 117.3, 115.0, 117.5]   # tab:results 10-seed mean
fmax_std = [2.4, 1.5, 1.4, 2.0, 1.8]
cm_cpi   = [1.54, 1.63, 1.83, 2.02, 2.18]       # CoreMark
diag_cpi = [1.38, 1.60, 1.66, 1.89, 2.11]       # Diagnostic
cm_mips   = [f / c for f, c in zip(fmax, cm_cpi)]
diag_mips = [f / c for f, c in zip(fmax, diag_cpi)]

# --- Throughput (CoreMark + Diagnostic) ---
x = np.arange(len(LABELS)); w = 0.38
fig, ax = plt.subplots(figsize=(3.6, 2.8))
b1 = ax.bar(x - w/2, cm_mips,   w, label="CoreMark",   color="#2196F3", edgecolor="black", linewidth=0.6)
b2 = ax.bar(x + w/2, diag_mips, w, label="Diagnostic", color="#FF9800", edgecolor="black", linewidth=0.6)
for bars in (b1, b2):
    for bar in bars:
        h = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2, h + 0.8, f"{h:.1f}",
                ha="center", va="bottom", fontsize=6.5)
ax.set_xticks(x); ax.set_xticklabels(LABELS)
plt.setp(ax.get_xticklabels(), rotation=15, ha="right")
ax.set_ylabel("Throughput (MIPS)")
ax.set_title("Effective Throughput ($F_{\\max}/$CPI)")
ax.set_ylim(0, max(diag_mips) * 1.30)
ax.legend(fontsize=8, loc="upper right", ncol=2, frameon=True, framealpha=0.9,
          columnspacing=1.0, handletextpad=0.4)
fig.tight_layout()
fig.savefig(os.path.join(FIG_DIR, "throughput_comparison.png"))
fig.savefig(os.path.join(FIG_DIR, "throughput_comparison.pdf"))
plt.close(fig)

# --- Published cores sanity check (ours = 10-seed Fmax) ---
cores = ["SERV", "PicoRV32", "VexRiscv", "Ibex", "CVA6",
         "4-stage (ours)", "5-stage (ours)", "6-stage (ours)",
         "7-stage (ours)", "8-stage (ours)"]
freqs = [300, 250, 200, 150, 80] + fmax
errs  = [0, 0, 0, 0, 0] + fmax_std
cpub  = ["#90CAF9"]*5 + ["#2196F3", "#4CAF50", "#FF9800", "#E91E63", "#9C27B0"]
fig, ax = plt.subplots(figsize=(7.0, 4.0))
y = np.arange(len(cores))
ax.barh(y, freqs, xerr=errs, capsize=3, color=cpub, edgecolor="black", linewidth=0.5)
ax.set_yticks(y); ax.set_yticklabels(cores, fontsize=9)
ax.invert_yaxis()
ax.set_xlabel("$F_{\\max}$ (MHz)")
ax.set_title("$F_{\\max}$ vs. Published RISC-V Soft Cores on Artix-7")
for i, (fr, er) in enumerate(zip(freqs, errs)):
    ax.text(fr + er + 4, i, f"{fr:.0f}", va="center", fontsize=8)
ax.set_xlim(0, 350)
fig.tight_layout()
fig.savefig(os.path.join(FIG_DIR, "published_cores_comparison.png"))
fig.savefig(os.path.join(FIG_DIR, "published_cores_comparison.pdf"))
plt.close(fig)

print("Regenerated throughput_comparison + published_cores_comparison (.png/.pdf)")
print("CoreMark MIPS :", {l: round(m,1) for l, m in zip(LABELS, cm_mips)})
print("Diagnostic MIPS:", {l: round(m,1) for l, m in zip(LABELS, diag_mips)})
