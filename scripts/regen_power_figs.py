#!/usr/bin/env python3
"""Regenerate power_comparison and efficiency_comparison figures with
workload-specific SAIF power (CoreMark), 5 pipeline depths. Matches the
5-depth style (colors/labels) used by generate_plots_5depth.py."""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIG_DIR = os.path.join(BASE, "paper", "figures")
os.makedirs(FIG_DIR, exist_ok=True)

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
COLORS = ["#2196F3", "#4CAF50", "#FF9800", "#E91E63", "#9C27B0"]

# Workload-specific SAIF power (CoreMark), Vivado report_power, Medium confidence
dynamic = [0.167, 0.162, 0.155, 0.157, 0.149]
static  = [0.069, 0.069, 0.069, 0.069, 0.069]
total   = [0.235, 0.231, 0.224, 0.225, 0.217]

# Efficiency = (Fmax / CoreMark CPI) / total power
fmax   = [70.4, 74.0, 117.3, 115.0, 117.5]   # 10-seed mean Fmax (MHz)
cm_cpi = [1.54, 1.63, 1.83, 2.02, 2.18]       # CoreMark CPI
mips   = [f / c for f, c in zip(fmax, cm_cpi)]
eff    = [m / p for m, p in zip(mips, total)]

W, H = 3.5, 2.8

# --- Power breakdown (stacked dynamic + static) ---
fig, ax = plt.subplots(figsize=(W, H))
b1 = ax.bar(LABELS, dynamic, color="tab:red", edgecolor="black", linewidth=0.6,
            label="Dynamic", width=0.6)
ax.bar(LABELS, static, bottom=dynamic, color="tab:cyan", edgecolor="black",
       linewidth=0.6, label="Static", width=0.6)
for i, t in enumerate(total):
    ax.text(i, t + 0.004, f"{t:.3f}", ha="center", va="bottom", fontsize=8)
ax.set_ylabel("Power (W)")
ax.set_title("On-Chip Power (CoreMark SAIF)")
ax.set_ylim(0, max(total) * 1.45)   # headroom so the legend sits clear above the bars
# upper-right has the most clearance (7/8-stage bars are the shortest); the extra
# headroom keeps the legend box above every total-power label
ax.legend(fontsize=8, loc="upper right", ncol=2, frameon=True, framealpha=0.9,
          columnspacing=1.2, handletextpad=0.4)
plt.setp(ax.get_xticklabels(), rotation=15, ha="right")
fig.tight_layout()
fig.savefig(os.path.join(FIG_DIR, "power_comparison.png"))
fig.savefig(os.path.join(FIG_DIR, "power_comparison.pdf"))
plt.close(fig)

# --- Efficiency (MIPS/W) ---
fig, ax = plt.subplots(figsize=(W, H))
bars = ax.bar(LABELS, eff, color=COLORS, edgecolor="black", linewidth=0.6, width=0.6)
for bar in bars:
    h = bar.get_height()
    ax.text(bar.get_x() + bar.get_width() / 2, h + 2, f"{h:.0f}",
            ha="center", va="bottom", fontsize=8)
ax.set_ylabel("MIPS / Watt")
ax.set_title("Energy Efficiency (CoreMark SAIF)")
ax.set_ylim(0, max(eff) * 1.18)
plt.setp(ax.get_xticklabels(), rotation=15, ha="right")
fig.tight_layout()
fig.savefig(os.path.join(FIG_DIR, "efficiency_comparison.png"))
fig.savefig(os.path.join(FIG_DIR, "efficiency_comparison.pdf"))
plt.close(fig)

print("Regenerated power_comparison and efficiency_comparison (.png/.pdf)")
print("Power total (W):", dict(zip(LABELS, total)))
print("Efficiency (MIPS/W):", {l: round(e) for l, e in zip(LABELS, eff)})
