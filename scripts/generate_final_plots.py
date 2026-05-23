#!/usr/bin/env python3
"""Generate all paper figures with COMPLETE 5-depth validated data.
Includes official CoreMark + 4 Embench-IoT + Dhrystone + Diagnostic."""

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import os

FIG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'paper', 'figures')
os.makedirs(FIG_DIR, exist_ok=True)

plt.rcParams.update({
    'font.size': 11, 'axes.labelsize': 12, 'axes.titlesize': 13,
    'xtick.labelsize': 10, 'ytick.labelsize': 10, 'legend.fontsize': 9,
    'figure.dpi': 200, 'savefig.bbox': 'tight', 'savefig.pad_inches': 0.15,
})

COLORS = ['#2196F3', '#4CAF50', '#FF9800', '#E91E63', '#9C27B0']
LABELS = ['4-stage', '5-stage', '6-stage', '7-stage', '8-stage']
DEPTHS = [4, 5, 6, 7, 8]

# SYNTHESIS DATA (from seed_results.log)
synth_fmax = {
    '4-stage': [75.9, 76.5, 73.1],
    '5-stage': [75.9, 77.4, 74.0],
    '6-stage': [115.5, 118.1, 118.1],
    '7-stage': [114.4, 118.8, 115.7],
    '8-stage': [119.2, 124.6, 117.2],
}
fmax_mean = {k: np.mean(v) for k, v in synth_fmax.items()}
fmax_std = {k: np.std(v, ddof=1) for k, v in synth_fmax.items()}

# COMPLETE VALIDATED BENCHMARK DATA (all 5 depths)

# Dhrystone: 2926 instr, 400 branches, 203 mispred (all depths identical)
dhry_cpi = [1.41, 1.48, 1.68, 1.85, 1.99]
dhry_fb = 400 / 2926  # 0.1367

# Diagnostic: 1367 instr, 360 branches, 69 mispred (all depths identical)
diag_cpi = [1.38, 1.60, 1.66, 1.89, 2.11]
diag_fb = 360 / 1367  # 0.2633

# CoreMark: 2893145 instr, 719810 branches
cm_cpi = [1.54, 1.63, 1.83, 2.02, 2.18]
cm_mispred = [145735, 145735, 154077, 147760, 147760]
cm_fb = 719810 / 2893145  # 0.2488

# Embench aha-mont64: 4453858 instr, 512593 branches
mont_cpi = [1.21, 1.21, 1.25, 1.32, 1.32]
mont_mispred = [140683, 140683, 139739, 139739, 139739]
mont_fb = 512593 / 4453858  # 0.1151

# Embench crc32: 4008648 instr, 174591 branches
crc_cpi = [1.30, 1.30, 1.39, 1.52, 1.56]
crc_mispred = [344, 344, 344, 344, 344]
crc_fb = 174591 / 4008648  # 0.04355

# Embench statemate: 3160225 instr, 376291 branches
sm_cpi = [1.21, 1.30, 1.37, 1.50, 1.69]
sm_mispred = [66603, 66603, 69933, 73263, 73263]
sm_fb = 376291 / 3160225  # 0.1191

# Embench edn: 2972527 instr, 338986 branches
edn_cpi = [1.48, 1.51, 1.66, 1.78, 1.95]
edn_mispred = [10452, 10452, 10452, 10452, 10452]
edn_fb = 338986 / 2972527  # 0.1140

ALL_BENCHMARKS = [
    ('Dhrystone', dhry_cpi, dhry_fb),
    ('Diagnostic', diag_cpi, diag_fb),
    ('CoreMark', cm_cpi, cm_fb),
    ('aha-mont64', mont_cpi, mont_fb),
    ('crc32', crc_cpi, crc_fb),
    ('statemate', sm_cpi, sm_fb),
    ('edn', edn_cpi, edn_fb),
]

# CPI MODEL FIT (7 workloads x 5 depths = 35 data points)
D_all = []
fb_all = []
cpi_all = []
for name, cpis, fb in ALL_BENCHMARKS:
    for i, d in enumerate(DEPTHS):
        D_all.append(d)
        fb_all.append(fb)
        cpi_all.append(cpis[i])

D_all = np.array(D_all)
fb_all = np.array(fb_all)
cpi_all = np.array(cpi_all)

# Linear model: CPI = a + b*D + c*fb
X = np.column_stack([np.ones(len(D_all)), D_all, fb_all])
beta = np.linalg.lstsq(X, cpi_all, rcond=None)[0]
a, b, c = beta
cpi_pred = X @ beta
ss_res = np.sum((cpi_all - cpi_pred)**2)
ss_tot = np.sum((cpi_all - np.mean(cpi_all))**2)
r2 = 1 - ss_res / ss_tot
n = len(cpi_all)
k = 3
mae = np.mean(np.abs(cpi_all - cpi_pred))
max_resid = np.max(np.abs(cpi_all - cpi_pred))

# AIC comparison
aic_linear = n * np.log(ss_res / n) + 2 * k

X2 = np.column_stack([np.ones(n), D_all, D_all * fb_all])
b2 = np.linalg.lstsq(X2, cpi_all, rcond=None)[0]
aic_inter = n * np.log(np.sum((cpi_all - X2 @ b2)**2) / n) + 2 * 3

X3 = np.column_stack([np.ones(n), D_all, D_all**2, fb_all])
b3 = np.linalg.lstsq(X3, cpi_all, rcond=None)[0]
aic_quad = n * np.log(np.sum((cpi_all - X3 @ b3)**2) / n) + 2 * 4

X4 = np.column_stack([np.ones(n), D_all, fb_all, D_all * fb_all])
b4 = np.linalg.lstsq(X4, cpi_all, rcond=None)[0]
aic_full = n * np.log(np.sum((cpi_all - X4 @ b4)**2) / n) + 2 * 4

print("=== CPI Model (35 data points: 7 workloads x 5 depths) ===")
print(f"  CPI = {a:.3f} + {b:.3f}*D + {c:.3f}*fb")
print(f"  R² = {r2:.3f}, MAE = {mae:.3f}, Max residual = {max_resid:.3f}")
print(f"  AIC: linear={aic_linear:.1f}, interaction={aic_inter:.1f}, quadratic={aic_quad:.1f}, full={aic_full:.1f}")

# PLOTS

# 1. Fmax comparison with error bars
fig, ax = plt.subplots(figsize=(7, 4))
x = np.arange(5)
means = [fmax_mean[n] for n in LABELS]
stds = [fmax_std[n] for n in LABELS]
bars = ax.bar(x, means, yerr=stds, capsize=5, color=COLORS, edgecolor='black', linewidth=0.5)
ax.set_xticks(x); ax.set_xticklabels(LABELS)
ax.set_ylabel('Fmax (MHz)'); ax.set_title('Maximum Clock Frequency (Post-Place-and-Route)')
ax.set_ylim(0, 145)
for bar, m, s in zip(bars, means, stds):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + s + 1.5,
            f'{m:.1f}', ha='center', va='bottom', fontsize=9, fontweight='bold')
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'fmax_comparison.png')); plt.close()

# 2. CPI comparison (all 7 workloads, grouped)
fig, ax = plt.subplots(figsize=(10, 5))
bench_names = [b[0] for b in ALL_BENCHMARKS]
n_bench = len(bench_names)
width = 0.15
x = np.arange(n_bench)
for i, (label, color) in enumerate(zip(LABELS, COLORS)):
    vals = [b[1][i] for b in ALL_BENCHMARKS]
    ax.bar(x + i*width - 2*width, vals, width, label=label, color=color, edgecolor='black', linewidth=0.3)
ax.set_xticks(x); ax.set_xticklabels(bench_names, fontsize=9)
ax.set_ylabel('CPI'); ax.set_title('CPI Across 7 Workloads and 5 Pipeline Depths')
ax.legend(loc='upper left', fontsize=8); ax.set_ylim(0, 2.5)
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'cpi_comparison.png')); plt.close()

# 3. CPI vs depth (scatter + model lines for all workloads)
fig, ax = plt.subplots(figsize=(7, 5))
markers = ['o', 's', 'D', '^', 'v', '<', '>']
bench_colors = ['#2196F3', '#FF9800', '#E91E63', '#4CAF50', '#9C27B0', '#795548', '#607D8B']
d_range = np.linspace(3.5, 8.5, 100)
for i, (name, cpis, fb) in enumerate(ALL_BENCHMARKS):
    ax.scatter(DEPTHS, cpis, color=bench_colors[i], s=50, zorder=5, marker=markers[i],
               label=f'{name} ($f_b$={fb:.3f})')
    cpi_line = a + b * d_range + c * fb
    ax.plot(d_range, cpi_line, color=bench_colors[i], linestyle='--', alpha=0.5, linewidth=1)
ax.set_xlabel('Pipeline Depth (stages)'); ax.set_ylabel('CPI')
ax.set_title(f'CPI vs. Pipeline Depth (35 observations)\n'
             f'Model: CPI = {a:.2f} + {b:.3f}D + {c:.2f}$f_b$ ($R^2$ = {r2:.2f})')
ax.legend(loc='upper left', fontsize=7, ncol=2); ax.set_xticks(DEPTHS)
ax.set_ylim(1.0, 2.4); ax.grid(True, alpha=0.3)
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'cpi_vs_depth.png')); plt.close()

# 4. Fmax vs depth with error bars
fig, ax = plt.subplots(figsize=(6, 4.5))
means_arr = np.array([fmax_mean[n] for n in LABELS])
stds_arr = np.array([fmax_std[n] for n in LABELS])
ax.errorbar(DEPTHS, means_arr, yerr=stds_arr, fmt='o-', capsize=5,
            color='#E91E63', markersize=8, linewidth=2, markerfacecolor='white', markeredgewidth=2)
for d, m, s in zip(DEPTHS, means_arr, stds_arr):
    ax.annotate(f'{m:.1f}', (d, m + s + 2), ha='center', fontsize=9, fontweight='bold')
ax.set_xlabel('Pipeline Depth (stages)'); ax.set_ylabel('Fmax (MHz)')
ax.set_title('Fmax vs. Pipeline Depth (3-seed mean and std)')
ax.set_xticks(DEPTHS); ax.set_ylim(60, 140); ax.grid(True, alpha=0.3)
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'fmax_vs_depth.png')); plt.close()

# 5. CoreMark/MHz comparison
fig, ax = plt.subplots(figsize=(7, 4))
cm_score = [cm_cpi[i] for i in range(5)]
cm_mhz = [10 * 1e6 / (cm_cpi[i] * 2893145 / fmax_mean[LABELS[i]]) for i in range(5)]
# CoreMark/MHz = iterations * 1e6 / cycles
cm_per_mhz = [10 * 1e6 / (c * 2893145 / 10e6) for c in [4481534, 4724937, 5310372, 5856929, 6323069]]
# Simpler: CoreMark/MHz = iterations / cycles * 1e6
cm_per_mhz = [10e6/4481534, 10e6/4724937, 10e6/5310372, 10e6/5856929, 10e6/6323069]
bars = ax.bar(np.arange(5), cm_per_mhz, color=COLORS, edgecolor='black', linewidth=0.5)
ax.set_xticks(np.arange(5)); ax.set_xticklabels(LABELS)
ax.set_ylabel('CoreMark/MHz'); ax.set_title('Official EEMBC CoreMark/MHz Score')
ax.set_ylim(0, 3)
for bar in bars:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.03,
            f'{bar.get_height():.2f}', ha='center', va='bottom', fontsize=9, fontweight='bold')
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'coremark_mhz.png')); plt.close()

# 6. Throughput (MIPS) using CoreMark CPI
fig, ax = plt.subplots(figsize=(7, 4.5))
mips_cm = [fmax_mean[LABELS[i]] / cm_cpi[i] for i in range(5)]
mips_diag = [fmax_mean[LABELS[i]] / diag_cpi[i] for i in range(5)]
width = 0.35
bars1 = ax.bar(np.arange(5) - width/2, mips_cm, width, label='CoreMark', color='#2196F3', edgecolor='black', linewidth=0.5)
bars2 = ax.bar(np.arange(5) + width/2, mips_diag, width, label='Diagnostic', color='#FF9800', edgecolor='black', linewidth=0.5)
ax.set_xticks(np.arange(5)); ax.set_xticklabels(LABELS)
ax.set_ylabel('Throughput (MIPS)'); ax.set_title('Effective Throughput Comparison')
ax.legend(loc='upper left'); ax.set_ylim(0, 90)
for bar in bars1:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
            f'{bar.get_height():.1f}', ha='center', va='bottom', fontsize=7)
for bar in bars2:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
            f'{bar.get_height():.1f}', ha='center', va='bottom', fontsize=7)
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'throughput_comparison.png')); plt.close()

# 7. Misprediction rate comparison (CoreMark + statemate show depth effect)
fig, ax = plt.subplots(figsize=(8, 4.5))
cm_mr = [m/719810*100 for m in cm_mispred]
sm_mr = [m/376291*100 for m in sm_mispred]
width = 0.35
bars1 = ax.bar(np.arange(5) - width/2, cm_mr, width, label='CoreMark', color='#2196F3', edgecolor='black', linewidth=0.5)
bars2 = ax.bar(np.arange(5) + width/2, sm_mr, width, label='statemate', color='#E91E63', edgecolor='black', linewidth=0.5)
ax.set_xticks(np.arange(5)); ax.set_xticklabels(LABELS)
ax.set_ylabel('Misprediction Rate (%)'); ax.set_title('Branch Misprediction Rate vs. Pipeline Depth')
ax.legend(); ax.set_ylim(0, 25)
for bar in bars1:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.2,
            f'{bar.get_height():.1f}%', ha='center', va='bottom', fontsize=8)
for bar in bars2:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.2,
            f'{bar.get_height():.1f}%', ha='center', va='bottom', fontsize=8)
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'mispred_comparison.png')); plt.close()

# 8. CPI overhead relative to 4-stage
fig, ax = plt.subplots(figsize=(8, 5))
bench_subset = [('CoreMark', cm_cpi), ('Diagnostic', diag_cpi), ('statemate', sm_cpi), ('edn', edn_cpi)]
width = 0.2
for j, (name, cpis) in enumerate(bench_subset):
    overhead = [(cpis[i]/cpis[0] - 1)*100 for i in range(1, 5)]
    ax.bar(np.arange(4) + j*width - 1.5*width, overhead, width, label=name, edgecolor='black', linewidth=0.3)
ax.set_xticks(np.arange(4)); ax.set_xticklabels(['5-stage', '6-stage', '7-stage', '8-stage'])
ax.set_ylabel('CPI Overhead vs. 4-stage (%)'); ax.set_title('CPI Overhead Relative to 4-Stage Baseline')
ax.legend(fontsize=8)
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'sensitivity_spacing.png')); plt.close()

# 9. Area comparison
luts_mean = {'4-stage': 6605, '5-stage': 6798, '6-stage': 7027, '7-stage': 7070, '8-stage': 7129}
ffs_mean = {'4-stage': 7956, '5-stage': 8124, '6-stage': 8413, '7-stage': 8489, '8-stage': 8625}
fig, ax = plt.subplots(figsize=(7, 4))
width = 0.35
bars1 = ax.bar(np.arange(5) - width/2, [luts_mean[n] for n in LABELS], width, label='Slice LUTs', color='#2196F3', edgecolor='black', linewidth=0.5)
bars2 = ax.bar(np.arange(5) + width/2, [ffs_mean[n] for n in LABELS], width, label='Slice Registers', color='#FF9800', edgecolor='black', linewidth=0.5)
ax.set_xticks(np.arange(5)); ax.set_xticklabels(LABELS)
ax.set_ylabel('Resource Count'); ax.set_title('LUT and Flip-Flop Utilization')
ax.legend(loc='upper left'); ax.set_ylim(0, 10500)
for bar in bars1:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 50,
            f'{bar.get_height():.0f}', ha='center', va='bottom', fontsize=7)
for bar in bars2:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 50,
            f'{bar.get_height():.0f}', ha='center', va='bottom', fontsize=7)
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'area_comparison.png')); plt.close()

# 10. Published cores comparison
fig, ax = plt.subplots(figsize=(8, 4.5))
cores = ['SERV', 'PicoRV32', 'VexRiscv', 'Ibex', 'CVA6',
         '4-stage\n(ours)', '5-stage\n(ours)', '6-stage\n(ours)', '7-stage\n(ours)', '8-stage\n(ours)']
freqs = [300, 250, 200, 150, 80,
         fmax_mean['4-stage'], fmax_mean['5-stage'], fmax_mean['6-stage'],
         fmax_mean['7-stage'], fmax_mean['8-stage']]
errs = [0, 0, 0, 0, 0,
        fmax_std['4-stage'], fmax_std['5-stage'], fmax_std['6-stage'],
        fmax_std['7-stage'], fmax_std['8-stage']]
colors_pub = ['#90CAF9']*5 + COLORS
bars = ax.barh(np.arange(len(cores)), freqs, xerr=errs, capsize=3,
               color=colors_pub, edgecolor='black', linewidth=0.5)
ax.set_yticks(np.arange(len(cores))); ax.set_yticklabels(cores, fontsize=9)
ax.set_xlabel('Fmax (MHz)'); ax.set_title('Fmax Comparison with Published RISC-V Soft Cores on Artix-7')
for i, (freq, err) in enumerate(zip(freqs, errs)):
    ax.text(freq + err + 3, i, f'{freq:.0f}', va='center', fontsize=8)
ax.set_xlim(0, 350)
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'published_cores_comparison.png')); plt.close()

# 11. Residual plot
fig, ax = plt.subplots(figsize=(6, 4))
residuals = cpi_all - cpi_pred
ax.scatter(cpi_pred, residuals, color='#E91E63', s=40, zorder=5)
ax.axhline(0, color='black', linewidth=0.5, linestyle='--')
ax.set_xlabel('Predicted CPI'); ax.set_ylabel('Residual (Measured - Predicted)')
ax.set_title('CPI Model Residuals (35 observations)'); ax.grid(True, alpha=0.3)
plt.tight_layout(); plt.savefig(os.path.join(FIG_DIR, 'cpi_residuals.png')); plt.close()

# Print summary
print("\n=== COMPLETE RESULTS SUMMARY ===")
print(f"\nCoreMark/MHz scores:")
for i, name in enumerate(LABELS):
    score = 10e6 / [4481534, 4724937, 5310372, 5856929, 6323069][i]
    print(f"  {name}: {score:.2f} CoreMark/MHz")

print(f"\nThroughput (MIPS, using CoreMark CPI):")
for i, name in enumerate(LABELS):
    print(f"  {name}: {fmax_mean[name]/cm_cpi[i]:.1f} MIPS")

print(f"\nMisprediction increase (CoreMark):")
print(f"  6s vs 4s/5s: {(154077-145735)/145735*100:.1f}% more mispredictions")
print(f"  Statemate 6s vs 4s/5s: {(69933-66603)/66603*100:.1f}% more")
print(f"  Statemate 7s/8s vs 4s/5s: {(73263-66603)/66603*100:.1f}% more")

print(f"\n=== All {11} plots generated ===")
