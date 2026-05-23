#!/usr/bin/env python3
"""Generate all paper figures for 5-depth pipeline comparison paper."""

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy import stats
import os

# Output directory
FIG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'paper', 'figures')
os.makedirs(FIG_DIR, exist_ok=True)

# Common style
plt.rcParams.update({
    'font.size': 11,
    'axes.labelsize': 12,
    'axes.titlesize': 13,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'legend.fontsize': 9,
    'figure.dpi': 200,
    'savefig.bbox': 'tight',
    'savefig.pad_inches': 0.15,
})

COLORS = ['#2196F3', '#4CAF50', '#FF9800', '#E91E63', '#9C27B0']
LABELS = ['4-stage', '5-stage', '6-stage', '7-stage', '8-stage']

# DATA

# Synthesis results: 3 seeds per variant
synth_fmax = {
    '4-stage': [75.9, 76.5, 73.1],
    '5-stage': [75.9, 77.4, 74.0],
    '6-stage': [115.5, 118.1, 118.1],
    '7-stage': [114.4, 118.8, 115.7],
    '8-stage': [119.2, 124.6, 117.2],
}
synth_luts = {
    '4-stage': [6606, 6604, 6606],
    '5-stage': [6797, 6805, 6792],
    '6-stage': [7028, 7025, 7028],
    '7-stage': [7073, 7065, 7073],
    '8-stage': [7124, 7140, 7124],
}
synth_ffs = {
    '4-stage': [7951, 7965, 7951],
    '5-stage': [8121, 8130, 8121],
    '6-stage': [8416, 8407, 8416],
    '7-stage': [8487, 8492, 8487],
    '8-stage': [8625, 8624, 8625],
}

# Compute means and stds
fmax_mean = {k: np.mean(v) for k, v in synth_fmax.items()}
fmax_std = {k: np.std(v, ddof=1) for k, v in synth_fmax.items()}
luts_mean = {k: np.mean(v) for k, v in synth_luts.items()}
ffs_mean = {k: np.mean(v) for k, v in synth_ffs.items()}

print("=== Synthesis Statistics ===")
for name in LABELS:
    print(f"  {name}: Fmax = {fmax_mean[name]:.1f} +/- {fmax_std[name]:.1f} MHz, "
          f"LUTs = {luts_mean[name]:.0f}, FFs = {ffs_mean[name]:.0f}")

# Benchmark data: Dhrystone (all 5 validated)
dhry = {
    'name': 'Dhrystone 2.1',
    'instr': 2926, 'branches': 400, 'mispred': [203, 203, 203, 203, 203],
    'cycles': [4134, 4334, 4938, 5440, 5840],
    'cpi': [1.41, 1.48, 1.68, 1.85, 1.99],
}

# Diagnostic (all 5 validated)
diag = {
    'name': 'Diagnostic',
    'instr': 1367, 'branches': 360, 'mispred': [69, 69, 69, 69, 69],
    'cycles': [1887, 2187, 2267, 2579, 2889],
    'cpi': [1.38, 1.60, 1.66, 1.89, 2.11],
}

# CoreMark-inspired (4s/5s/6s validated only)
cm = {
    'name': 'CoreMark-insp.',
    'instr': 17712, 'branches': 3763, 'mispred': [687, 687, 766],
    'cycles': [26109, 26767, 29467],
    'cpi': [1.47, 1.51, 1.66],
    'depths': [4, 5, 6],
}

# CRC-32 (5s/6s validated)
crc = {
    'name': 'CRC-32',
    'instr': 238121, 'branches': 108850, 'mispred': [33950, 33785],
    'cycles': [485885, 551622],
    'cpi': [2.04, 2.31],
    'depths': [5, 6],
}

# Sort (5s/6s validated)
sort_data = {
    'name': 'Sort',
    'instr': 191882, 'branches': 51635, 'mispred': [2464, 2635],
    'cycles': [296781, 302536],
    'cpi': [1.54, 1.57],
    'depths': [5, 6],
}

# CPI MODEL FIT
# Fit CPI = a + b*D + c*fb using Dhrystone + Diagnostic (10 points)
depths_all = [4, 5, 6, 7, 8]
fb_dhry = dhry['branches'] / dhry['instr']  # 0.1367
fb_diag = diag['branches'] / diag['instr']  # 0.2633

# Design matrix
D_vals = np.array(depths_all * 2)
fb_vals = np.array([fb_dhry]*5 + [fb_diag]*5)
cpi_vals = np.array(dhry['cpi'] + diag['cpi'])

X = np.column_stack([np.ones(10), D_vals, fb_vals])
# Least squares fit
beta, residuals, rank, sv = np.linalg.lstsq(X, cpi_vals, rcond=None)
a, b, c = beta

cpi_pred = X @ beta
ss_res = np.sum((cpi_vals - cpi_pred)**2)
ss_tot = np.sum((cpi_vals - np.mean(cpi_vals))**2)
r_squared = 1 - ss_res / ss_tot
n = len(cpi_vals)
k = 3  # parameters
aic_linear = n * np.log(ss_res / n) + 2 * k
mae = np.mean(np.abs(cpi_vals - cpi_pred))
max_resid = np.max(np.abs(cpi_vals - cpi_pred))
resid_std = np.std(cpi_vals - cpi_pred, ddof=k)

print(f"\n=== CPI Model: CPI = {a:.3f} + {b:.3f}*D + {c:.3f}*fb ===")
print(f"  R² = {r_squared:.3f}")
print(f"  AIC = {aic_linear:.1f}")
print(f"  MAE = {mae:.3f}")
print(f"  Max residual = {max_resid:.3f}")
print(f"  Residual std = {resid_std:.3f}")
print(f"  df = {n - k}")
print(f"  Residuals: {cpi_vals - cpi_pred}")

# Alternative models for AIC comparison
# Model 2: Interaction - CPI = a + b*D + c*D*fb
X2 = np.column_stack([np.ones(10), D_vals, D_vals * fb_vals])
beta2 = np.linalg.lstsq(X2, cpi_vals, rcond=None)[0]
ss_res2 = np.sum((cpi_vals - X2 @ beta2)**2)
aic_interaction = n * np.log(ss_res2 / n) + 2 * 3

# Model 3: Quadratic - CPI = a + b*D + c*D^2 + d*fb
X3 = np.column_stack([np.ones(10), D_vals, D_vals**2, fb_vals])
beta3 = np.linalg.lstsq(X3, cpi_vals, rcond=None)[0]
ss_res3 = np.sum((cpi_vals - X3 @ beta3)**2)
aic_quadratic = n * np.log(ss_res3 / n) + 2 * 4

# Model 4: Full - CPI = a + b*D + c*fb + d*D*fb
X4 = np.column_stack([np.ones(10), D_vals, fb_vals, D_vals * fb_vals])
beta4 = np.linalg.lstsq(X4, cpi_vals, rcond=None)[0]
ss_res4 = np.sum((cpi_vals - X4 @ beta4)**2)
aic_full = n * np.log(ss_res4 / n) + 2 * 4

r2_interaction = 1 - ss_res2 / ss_tot
r2_quadratic = 1 - ss_res3 / ss_tot
r2_full = 1 - ss_res4 / ss_tot

print(f"\n=== AIC Comparison ===")
print(f"  Linear (D, fb):       AIC={aic_linear:.1f}, R²={r_squared:.3f}")
print(f"  Interaction (D, D*fb): AIC={aic_interaction:.1f}, R²={r2_interaction:.3f}")
print(f"  Quadratic (D, D², fb): AIC={aic_quadratic:.1f}, R²={r2_quadratic:.3f}")
print(f"  Full (D, fb, D*fb):    AIC={aic_full:.1f}, R²={r2_full:.3f}")

# Throughput and DMIPS calculations
print("\n=== Throughput (using Diagnostic CPI) ===")
for i, name in enumerate(LABELS):
    fm = fmax_mean[name]
    cpi = diag['cpi'][i]
    mips = fm / cpi
    print(f"  {name}: {mips:.1f} MIPS ({fm:.1f} MHz / {cpi:.2f} CPI)")

print("\n=== DMIPS/MHz (Dhrystone) ===")
for i, name in enumerate(LABELS):
    fm = fmax_mean[name]
    cpi = dhry['cpi'][i]
    dmips_per_mhz = 1.0 / (cpi * 1757) * 1e6  # DMIPS/MHz = Dhrystones_per_sec / 1757 / Fmax
    # Actually: DMIPS = (Fmax / CPI) * (1/1757) * (Dhrystones_per_loop)
    # For 100 iterations in 2926 instr: Dhrystones/sec = Fmax*1e6 / (cycles_per_100iter) * 100
    dhrystones_per_sec = fm * 1e6 / dhry['cycles'][i] * 100
    dmips = dhrystones_per_sec / 1757
    print(f"  {name}: DMIPS={dmips:.0f}, DMIPS/MHz={dmips/fm:.2f}")

# PLOTS

# 1. Fmax comparison bar chart with error bars
fig, ax = plt.subplots(figsize=(7, 4))
x = np.arange(5)
means = [fmax_mean[n] for n in LABELS]
stds = [fmax_std[n] for n in LABELS]
bars = ax.bar(x, means, yerr=stds, capsize=5, color=COLORS, edgecolor='black', linewidth=0.5)
ax.set_xticks(x)
ax.set_xticklabels(LABELS)
ax.set_ylabel('Fmax (MHz)')
ax.set_title('Maximum Clock Frequency (Post-Place-and-Route)')
ax.set_ylim(0, 145)
for bar, m, s in zip(bars, means, stds):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + s + 1.5,
            f'{m:.1f}', ha='center', va='bottom', fontsize=9, fontweight='bold')
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'fmax_comparison.png'))
plt.close()

# 2. Area comparison (grouped bar: LUTs and FFs)
fig, ax = plt.subplots(figsize=(7, 4))
x = np.arange(5)
width = 0.35
luts = [luts_mean[n] for n in LABELS]
ffs = [ffs_mean[n] for n in LABELS]
bars1 = ax.bar(x - width/2, luts, width, label='Slice LUTs', color='#2196F3', edgecolor='black', linewidth=0.5)
bars2 = ax.bar(x + width/2, ffs, width, label='Slice Registers', color='#FF9800', edgecolor='black', linewidth=0.5)
ax.set_xticks(x)
ax.set_xticklabels(LABELS)
ax.set_ylabel('Resource Count')
ax.set_title('LUT and Flip-Flop Utilization')
ax.legend(loc='upper left')
ax.set_ylim(0, 10500)
for bar in bars1:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 50,
            f'{bar.get_height():.0f}', ha='center', va='bottom', fontsize=7)
for bar in bars2:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 50,
            f'{bar.get_height():.0f}', ha='center', va='bottom', fontsize=7)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'area_comparison.png'))
plt.close()

# 3. CPI comparison (grouped bar: Dhrystone + Diagnostic)
fig, ax = plt.subplots(figsize=(7, 4.5))
x = np.arange(5)
width = 0.35
bars1 = ax.bar(x - width/2, dhry['cpi'], width, label='Dhrystone 2.1', color='#2196F3', edgecolor='black', linewidth=0.5)
bars2 = ax.bar(x + width/2, diag['cpi'], width, label='Diagnostic', color='#FF9800', edgecolor='black', linewidth=0.5)
ax.set_xticks(x)
ax.set_xticklabels(LABELS)
ax.set_ylabel('CPI (Cycles Per Instruction)')
ax.set_title('CPI Comparison Across Pipeline Depths')
ax.legend(loc='upper left')
ax.set_ylim(0, 2.5)
for bar in bars1:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
            f'{bar.get_height():.2f}', ha='center', va='bottom', fontsize=8)
for bar in bars2:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
            f'{bar.get_height():.2f}', ha='center', va='bottom', fontsize=8)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'cpi_comparison.png'))
plt.close()

# 4. Throughput comparison (MIPS, Diagnostic + Dhrystone)
fig, ax = plt.subplots(figsize=(7, 4.5))
x = np.arange(5)
width = 0.35
mips_dhry = [fmax_mean[n] / dhry['cpi'][i] for i, n in enumerate(LABELS)]
mips_diag = [fmax_mean[n] / diag['cpi'][i] for i, n in enumerate(LABELS)]
bars1 = ax.bar(x - width/2, mips_dhry, width, label='Dhrystone 2.1', color='#2196F3', edgecolor='black', linewidth=0.5)
bars2 = ax.bar(x + width/2, mips_diag, width, label='Diagnostic', color='#FF9800', edgecolor='black', linewidth=0.5)
ax.set_xticks(x)
ax.set_xticklabels(LABELS)
ax.set_ylabel('Throughput (MIPS)')
ax.set_title('Effective Throughput Comparison')
ax.legend(loc='upper left')
ax.set_ylim(0, 100)
for bar in bars1:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
            f'{bar.get_height():.1f}', ha='center', va='bottom', fontsize=7)
for bar in bars2:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
            f'{bar.get_height():.1f}', ha='center', va='bottom', fontsize=7)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'throughput_comparison.png'))
plt.close()

# 5. CPI vs pipeline depth (scatter + model line)
fig, ax = plt.subplots(figsize=(6, 4.5))
depths = np.array([4, 5, 6, 7, 8])
ax.scatter(depths, dhry['cpi'], color='#2196F3', s=80, zorder=5, label=f'Dhrystone ($f_b$={fb_dhry:.3f})')
ax.scatter(depths, diag['cpi'], color='#FF9800', s=80, zorder=5, marker='s', label=f'Diagnostic ($f_b$={fb_diag:.3f})')

# Model lines
d_range = np.linspace(3.5, 8.5, 100)
for fb_val, color, ls in [(fb_dhry, '#2196F3', '-'), (fb_diag, '#FF9800', '--')]:
    cpi_line = a + b * d_range + c * fb_val
    ax.plot(d_range, cpi_line, color=color, linestyle=ls, alpha=0.7)

ax.set_xlabel('Pipeline Depth (stages)')
ax.set_ylabel('CPI')
ax.set_title(f'CPI vs. Pipeline Depth\n'
             f'Model: CPI = {a:.2f} + {b:.3f}D + {c:.2f}$f_b$ ($R^2$ = {r_squared:.2f})')
ax.legend(loc='upper left')
ax.set_xticks(depths)
ax.set_ylim(1.1, 2.3)
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'cpi_vs_depth.png'))
plt.close()

# 6. Fmax vs pipeline depth (scatter + error bars)
fig, ax = plt.subplots(figsize=(6, 4.5))
means_arr = np.array([fmax_mean[n] for n in LABELS])
stds_arr = np.array([fmax_std[n] for n in LABELS])
ax.errorbar(depths, means_arr, yerr=stds_arr, fmt='o-', capsize=5,
            color='#E91E63', markersize=8, linewidth=2, markerfacecolor='white',
            markeredgewidth=2)
for d, m, s in zip(depths, means_arr, stds_arr):
    ax.annotate(f'{m:.1f}', (d, m + s + 2), ha='center', fontsize=9, fontweight='bold')
ax.set_xlabel('Pipeline Depth (stages)')
ax.set_ylabel('Fmax (MHz)')
ax.set_title('Fmax vs. Pipeline Depth (3-seed mean and std)')
ax.set_xticks(depths)
ax.set_ylim(60, 140)
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'fmax_vs_depth.png'))
plt.close()

# 7. CPI overhead relative to 4-stage baseline
fig, ax = plt.subplots(figsize=(7, 4.5))
x = np.arange(4)  # 5s, 6s, 7s, 8s
width = 0.35
overhead_dhry = [(dhry['cpi'][i+1] / dhry['cpi'][0] - 1) * 100 for i in range(4)]
overhead_diag = [(diag['cpi'][i+1] / diag['cpi'][0] - 1) * 100 for i in range(4)]
bars1 = ax.bar(x - width/2, overhead_dhry, width, label='Dhrystone 2.1', color='#2196F3', edgecolor='black', linewidth=0.5)
bars2 = ax.bar(x + width/2, overhead_diag, width, label='Diagnostic', color='#FF9800', edgecolor='black', linewidth=0.5)
ax.set_xticks(x)
ax.set_xticklabels(['5-stage', '6-stage', '7-stage', '8-stage'])
ax.set_ylabel('CPI Overhead vs. 4-stage (%)')
ax.set_title('CPI Overhead Relative to 4-Stage Baseline')
ax.legend(loc='upper left')
for bar in bars1:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
            f'{bar.get_height():.1f}%', ha='center', va='bottom', fontsize=8)
for bar in bars2:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
            f'{bar.get_height():.1f}%', ha='center', va='bottom', fontsize=8)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'sensitivity_spacing.png'))
plt.close()

# 8. Published cores comparison (update with 5 variants)
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
ax.set_yticks(np.arange(len(cores)))
ax.set_yticklabels(cores, fontsize=9)
ax.set_xlabel('Fmax (MHz)')
ax.set_title('Fmax Comparison with Published RISC-V Soft Cores on Artix-7')
for i, (freq, err) in enumerate(zip(freqs, errs)):
    ax.text(freq + err + 3, i, f'{freq:.0f}', va='center', fontsize=8)
ax.set_xlim(0, 350)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'published_cores_comparison.png'))
plt.close()

# 9. CoreMark CPI for 4s/5s/6s (supplementary)
fig, ax = plt.subplots(figsize=(5, 3.5))
x_cm = np.arange(3)
bars = ax.bar(x_cm, cm['cpi'], color=[COLORS[0], COLORS[1], COLORS[2]], edgecolor='black', linewidth=0.5)
ax.set_xticks(x_cm)
ax.set_xticklabels(['4-stage', '5-stage', '6-stage'])
ax.set_ylabel('CPI')
ax.set_title('CoreMark-Inspired CPI (Validated Depths)')
ax.set_ylim(0, 2.0)
for bar in bars:
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
            f'{bar.get_height():.2f}', ha='center', va='bottom', fontsize=9, fontweight='bold')
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'coremark_cpi.png'))
plt.close()

# 10. Misprediction rates - CoreMark shows depth-dependent effect
fig, ax = plt.subplots(figsize=(6, 4))
# CoreMark misprediction rates
cm_mr = [m/cm['branches']*100 for m in cm['mispred']]
ax.bar([0, 1, 2], cm_mr, color=[COLORS[0], COLORS[1], COLORS[2]], edgecolor='black', linewidth=0.5)
ax.set_xticks([0, 1, 2])
ax.set_xticklabels(['4-stage', '5-stage', '6-stage'])
ax.set_ylabel('Misprediction Rate (%)')
ax.set_title('CoreMark-Inspired: Branch Misprediction Rate')
ax.set_ylim(0, 25)
for i, mr in enumerate(cm_mr):
    ax.text(i, mr + 0.3, f'{mr:.1f}%', ha='center', fontsize=9, fontweight='bold')
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'mispred_comparison.png'))
plt.close()

# 11. Residual plot for CPI model
fig, ax = plt.subplots(figsize=(6, 4))
residuals_all = cpi_vals - cpi_pred
ax.scatter(cpi_pred, residuals_all, color='#E91E63', s=60, zorder=5)
ax.axhline(0, color='black', linewidth=0.5, linestyle='--')
ax.set_xlabel('Predicted CPI')
ax.set_ylabel('Residual (Measured - Predicted)')
ax.set_title('CPI Model Residuals')
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'cpi_residuals.png'))
plt.close()

# Print all key numbers for paper
print("\n=== Key Numbers for Paper ===")
print(f"\nFmax improvement 6s vs 4s: {(fmax_mean['6-stage']/fmax_mean['4-stage']-1)*100:.1f}%")
print(f"Fmax improvement 6s vs 5s: {(fmax_mean['6-stage']/fmax_mean['5-stage']-1)*100:.1f}%")
print(f"Fmax 8s vs 6s: {(fmax_mean['8-stage']/fmax_mean['6-stage']-1)*100:.1f}%")
print(f"Fmax 7s vs 6s: {(fmax_mean['7-stage']/fmax_mean['6-stage']-1)*100:.1f}%")

print(f"\nLUT increase 5s vs 4s: {(luts_mean['5-stage']/luts_mean['4-stage']-1)*100:.1f}% ({luts_mean['5-stage']-luts_mean['4-stage']:.0f} LUTs)")
print(f"LUT increase 6s vs 4s: {(luts_mean['6-stage']/luts_mean['4-stage']-1)*100:.1f}% ({luts_mean['6-stage']-luts_mean['4-stage']:.0f} LUTs)")
print(f"LUT increase 8s vs 4s: {(luts_mean['8-stage']/luts_mean['4-stage']-1)*100:.1f}% ({luts_mean['8-stage']-luts_mean['4-stage']:.0f} LUTs)")

print(f"\nFF increase 5s vs 4s: {ffs_mean['5-stage']-ffs_mean['4-stage']:.0f} ({(ffs_mean['5-stage']/ffs_mean['4-stage']-1)*100:.1f}%)")
print(f"FF increase 8s vs 4s: {ffs_mean['8-stage']-ffs_mean['4-stage']:.0f} ({(ffs_mean['8-stage']/ffs_mean['4-stage']-1)*100:.1f}%)")

# CPI overheads
print(f"\nCPI overhead 8s vs 4s Dhrystone: {(dhry['cpi'][4]/dhry['cpi'][0]-1)*100:.1f}%")
print(f"CPI overhead 8s vs 4s Diagnostic: {(diag['cpi'][4]/diag['cpi'][0]-1)*100:.1f}%")
print(f"CPI delta per depth (Dhrystone): {(dhry['cpi'][4]-dhry['cpi'][0])/4:.3f}")
print(f"CPI delta per depth (Diagnostic): {(diag['cpi'][4]-diag['cpi'][0])/4:.3f}")

# Throughput
for i, name in enumerate(LABELS):
    fm = fmax_mean[name]
    cpi_d = diag['cpi'][i]
    cpi_dh = dhry['cpi'][i]
    print(f"\n{name}:")
    print(f"  Throughput (Diag): {fm/cpi_d:.1f} MIPS")
    print(f"  Throughput (Dhry): {fm/cpi_dh:.1f} MIPS")
    dhrystones_per_sec = fm * 1e6 / dhry['cycles'][i] * 100
    dmips = dhrystones_per_sec / 1757
    print(f"  DMIPS: {dmips:.0f}")

# CoreMark misprediction analysis
print(f"\nCoreMark mispred increase 6s vs 4s: {(766-687)/687*100:.1f}% ({766-687} more)")

print("\n=== All plots generated ===")
