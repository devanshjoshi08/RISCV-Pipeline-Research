#!/usr/bin/env python3
"""Regenerate bram_comparison with LUT-based Fmax consistent with tab:results
(10-seed means) and BRAM-based Fmax from the BRAM experiment, 5 depths,
IEEE serif style matching the other figures."""
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
lut  = [70.4, 74.0, 117.3, 115.0, 117.5]   # tab:results 10-seed mean Fmax
bram = [69.3, 73.7, 121.5, 120.9, 121.2]   # BRAM-based instruction memory

x = np.arange(len(LABELS)); w = 0.38
fig, ax = plt.subplots(figsize=(3.6, 2.8))
b1 = ax.bar(x - w/2, lut,  w, label="LUT-based",  color="#2196F3", edgecolor="black", linewidth=0.6)
b2 = ax.bar(x + w/2, bram, w, label="BRAM-based", color="#FF9800", edgecolor="black", linewidth=0.6)
for bars in (b1, b2):
    for bar in bars:
        h = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2, h + 1.5, f"{h:.1f}",
                ha="center", va="bottom", fontsize=6.5)
ax.set_xticks(x); ax.set_xticklabels(LABELS)
plt.setp(ax.get_xticklabels(), rotation=15, ha="right")
ax.set_ylabel("$F_{\\max}$ (MHz)")
ax.set_title("LUT vs. BRAM Instruction Memory")
ax.set_ylim(0, max(bram) * 1.30)            # headroom; legend over the short 4/5-stage bars
ax.legend(fontsize=8, loc="upper left", frameon=True, framealpha=0.9)
fig.tight_layout()
fig.savefig(os.path.join(FIG_DIR, "bram_comparison.png"))
fig.savefig(os.path.join(FIG_DIR, "bram_comparison.pdf"))
plt.close(fig)
print("Regenerated bram_comparison (.png/.pdf)")
print("LUT :", dict(zip(LABELS, lut)))
print("BRAM:", dict(zip(LABELS, bram)))
