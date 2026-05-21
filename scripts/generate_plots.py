#!/usr/bin/env python3
"""
Generate publication-quality comparison plots for RISC-V RV32IM pipeline paper.
Compares 5-stage, 6-stage, and 7-stage pipelines on Artix-7 FPGA.
Uses real benchmark data from Vivado simulation.
"""

import json
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIG_DIR = os.path.join(BASE, "paper", "figures")
RESULTS_DIR = os.path.join(BASE, "results")
os.makedirs(FIG_DIR, exist_ok=True)
os.makedirs(RESULTS_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Synthesis Data
# ---------------------------------------------------------------------------
variants = ["5-stage", "6-stage", "7-stage"]
colors = ["#4878CF", "#E8833A", "#6ACC65"]

synth = {
    "5-stage": {"Fmax_MHz": 77.8,  "LUTs": 6793, "FFs": 8129, "DSPs": 12,
                "Power_W": 0.299, "Dynamic_W": 0.230},
    "6-stage": {"Fmax_MHz": 121.1, "LUTs": 7015, "FFs": 8403, "DSPs": 12,
                "Power_W": 0.298, "Dynamic_W": 0.230},
    "7-stage": {"Fmax_MHz": 115.3, "LUTs": 7069, "FFs": 8489, "DSPs": 12,
                "Power_W": 0.300, "Dynamic_W": 0.231},
}

# ---------------------------------------------------------------------------
# Benchmark Data (from simulation)
# ---------------------------------------------------------------------------
diag = {
    "5-stage": {"cycles": 2187, "instrs": 1367, "branches": 360, "mispred": 69},
    "6-stage": {"cycles": 2267, "instrs": 1367, "branches": 360, "mispred": 69},
    "7-stage": {"cycles": 2579, "instrs": 1367, "branches": 360, "mispred": 69},
}

bench_branch = {
    "5-stage": {"cycles": 12176, "instrs": 7106, "branches": 2013, "mispred": 572},
    "6-stage": {"cycles": 13520, "instrs": 7106, "branches": 2013, "mispred": 686},
    "7-stage": {"cycles": 15302, "instrs": 7106, "branches": 2013, "mispred": 781},
}

bench_compute = {
    "5-stage": {"cycles": 13341, "instrs": 9913, "branches": 1158, "mispred": 126},
    "6-stage": {"cycles": 14143, "instrs": 9913, "branches": 1158, "mispred": 126},
    "7-stage": {"cycles": 15478, "instrs": 9913, "branches": 1158, "mispred": 139},
}

dhrystone = {
    "5-stage": {"cycles": 4334, "instrs": 2926, "branches": 400, "mispred": 203, "dhrystones": 100},
    "6-stage": {"cycles": 4938, "instrs": 2926, "branches": 400, "mispred": 203, "dhrystones": 100},
    "7-stage": {"cycles": 5440, "instrs": 2926, "branches": 400, "mispred": 203, "dhrystones": 100},
}

coremark = {
    "5-stage": {"cycles": 26767, "instrs": 17712, "branches": 3763, "mispred": 687, "iterations": 10},
    "6-stage": {"cycles": 29467, "instrs": 17712, "branches": 3763, "mispred": 766, "iterations": 10},
    "7-stage": {"cycles": 32476, "instrs": 17712, "branches": 3763, "mispred": 838, "iterations": 10},
}

bench_crc32 = {
    "5-stage": {"cycles": 485885, "instrs": 238121, "branches": 108850, "mispred": 33950},
    "6-stage": {"cycles": 551622, "instrs": 238121, "branches": 108850, "mispred": 33785},
    "7-stage": {"cycles": 614352, "instrs": 238121, "branches": 108850, "mispred": 33650},
}

bench_sort = {
    "5-stage": {"cycles": 296781, "instrs": 191882, "branches": 51635, "mispred": 2464},
    "6-stage": {"cycles": 302536, "instrs": 191882, "branches": 51635, "mispred": 2635},
    "7-stage": {"cycles": 326199, "instrs": 191882, "branches": 51635, "mispred": 2790},
}

# Derived metrics
for v in variants:
    s = synth[v]
    s["Static_W"] = round(s["Power_W"] - s["Dynamic_W"], 4)
    d = diag[v]
    d["CPI"] = round(d["cycles"] / d["instrs"], 2)
    d["mispred_rate"] = round(d["mispred"] / d["branches"] * 100, 1)
    s["CPI_diag"] = d["CPI"]
    # Dhrystone metrics
    dh = dhrystone[v]
    dh["CPI"] = round(dh["cycles"] / dh["instrs"], 2)
    dh["mispred_rate"] = round(dh["mispred"] / dh["branches"] * 100, 1)
    dh["dhry_per_sec"] = round(dh["dhrystones"] / dh["cycles"] * s["Fmax_MHz"] * 1e6)
    dh["DMIPS"] = round(dh["dhry_per_sec"] / 1757, 1)
    dh["DMIPS_per_MHz"] = round(dh["DMIPS"] / s["Fmax_MHz"], 4)
    # CoreMark metrics
    cm = coremark[v]
    cm["CPI"] = round(cm["cycles"] / cm["instrs"], 2)
    cm["mispred_rate"] = round(cm["mispred"] / cm["branches"] * 100, 1)
    # CRC32 and Sort
    cr = bench_crc32[v]
    cr["CPI"] = round(cr["cycles"] / cr["instrs"], 2)
    cr["mispred_rate"] = round(cr["mispred"] / cr["branches"] * 100, 1)
    sr = bench_sort[v]
    sr["CPI"] = round(sr["cycles"] / sr["instrs"], 2)
    sr["mispred_rate"] = round(sr["mispred"] / sr["branches"] * 100, 1)

for v in variants:
    bb = bench_branch[v]
    bb["CPI"] = round(bb["cycles"] / bb["instrs"], 2)
    bb["mispred_rate"] = round(bb["mispred"] / bb["branches"] * 100, 1)
    bc = bench_compute[v]
    bc["CPI"] = round(bc["cycles"] / bc["instrs"], 2)
    bc["mispred_rate"] = round(bc["mispred"] / bc["branches"] * 100, 1)

# Throughput and efficiency using workload-averaged CPI
for v in variants:
    s = synth[v]
    avg_cpi = (diag[v]["CPI"] + bench_branch[v]["CPI"] + bench_compute[v]["CPI"]) / 3
    s["CPI_avg"] = round(avg_cpi, 2)
    s["Throughput_MIPS"] = round(s["Fmax_MHz"] / avg_cpi, 1)
    s["Efficiency_MIPS_W"] = round(s["Throughput_MIPS"] / s["Power_W"], 1)

# Save all data
all_data = {"synthesis": synth, "diagnostic": diag, "dhrystone": dhrystone,
            "coremark": coremark, "crc32": bench_crc32, "sort": bench_sort,
            "branch_heavy": bench_branch, "compute_heavy": bench_compute}
json_path = os.path.join(RESULTS_DIR, "synthesis_results.json")
with open(json_path, "w") as f:
    json.dump(all_data, f, indent=2)
print(f"Saved JSON: {json_path}")

# ---------------------------------------------------------------------------
# Style - clean, modern publication look
# ---------------------------------------------------------------------------
IEEE_WIDTH = 3.5
IEEE_HEIGHT = 2.8
FONT_SIZE = 10
LABEL_FS = 8  # bar label font size

plt.rcParams.update({
    "font.family": "serif",
    "font.serif": ["Times New Roman", "DejaVu Serif", "serif"],
    "font.size": FONT_SIZE,
    "axes.labelsize": FONT_SIZE + 1,
    "axes.titlesize": FONT_SIZE + 2,
    "axes.titleweight": "bold",
    "xtick.labelsize": FONT_SIZE,
    "ytick.labelsize": FONT_SIZE,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "grid.alpha": 0.3,
    "grid.linestyle": "--",
    "figure.dpi": 150,
    "savefig.dpi": 300,
    "legend.framealpha": 0.9,
    "legend.edgecolor": "0.8",
})


def save(fig, name):
    path = os.path.join(FIG_DIR, name)
    fig.savefig(path, bbox_inches="tight", dpi=300)
    plt.close(fig)
    print(f"Saved: {path}")


def bar_labels(ax, bars, fmt="{:.1f}", offset=0.5, fs=None):
    if fs is None:
        fs = FONT_SIZE - 2
    for bar in bars:
        h = bar.get_height()
        ax.text(bar.get_x() + bar.get_width() / 2, h + offset,
                fmt.format(h), ha="center", va="bottom", fontsize=fs)


# ===========================================================================
# Fig 1: Fmax comparison
# ===========================================================================
fig, ax = plt.subplots(figsize=(IEEE_WIDTH, IEEE_HEIGHT))
vals = [synth[v]["Fmax_MHz"] for v in variants]
bars = ax.bar(variants, vals, color=colors, edgecolor="black", linewidth=0.6, width=0.55)
bar_labels(ax, bars, fmt="{:.1f}", offset=2, fs=LABEL_FS+1)
ax.set_ylabel("$F_{max}$ (MHz)")
ax.set_title("Maximum Clock Frequency")
ax.set_ylim(0, max(vals) * 1.18)
fig.tight_layout()
save(fig, "fmax_comparison.png")

# ===========================================================================
# Fig 2: Area comparison
# ===========================================================================
fig, ax = plt.subplots(figsize=(IEEE_WIDTH, IEEE_HEIGHT))
x = np.arange(len(variants))
w = 0.30
luts = [synth[v]["LUTs"] for v in variants]
ffs  = [synth[v]["FFs"]  for v in variants]
b1 = ax.bar(x - w/2, luts, w, label="LUTs", color=colors[0], edgecolor="black", linewidth=0.6)
b2 = ax.bar(x + w/2, ffs,  w, label="FFs",  color=colors[1], edgecolor="black", linewidth=0.6)
bar_labels(ax, b1, fmt="{:.0f}", offset=120, fs=LABEL_FS)
bar_labels(ax, b2, fmt="{:.0f}", offset=120, fs=LABEL_FS)
ax.set_xticks(x)
ax.set_xticklabels(variants)
ax.set_ylabel("Resource Count")
ax.set_title("FPGA Resource Utilization")
ax.set_ylim(0, max(max(luts), max(ffs)) * 1.22)
ax.legend(fontsize=FONT_SIZE - 2, loc="lower right")
fig.tight_layout()
save(fig, "area_comparison.png")

# ===========================================================================
# Fig 3: Power comparison
# ===========================================================================
fig, ax = plt.subplots(figsize=(IEEE_WIDTH, IEEE_HEIGHT))
dyn    = [synth[v]["Dynamic_W"] for v in variants]
static = [synth[v]["Static_W"]  for v in variants]
b1 = ax.bar(variants, dyn, color="tab:red", edgecolor="black", linewidth=0.6,
            label="Dynamic", width=0.55)
ax.bar(variants, static, bottom=dyn, color="tab:cyan", edgecolor="black",
       linewidth=0.6, label="Static", width=0.55)
for i, v in enumerate(variants):
    total = synth[v]["Power_W"]
    ax.text(i, total + 0.008, f"{total:.3f} W", ha="center", va="bottom",
            fontsize=LABEL_FS)
ax.set_ylabel("Power (W)")
ax.set_title("Power Consumption Breakdown")
ax.set_ylim(0, 0.42)
ax.legend(fontsize=FONT_SIZE - 2, loc="upper right")
fig.tight_layout()
save(fig, "power_comparison.png")

# ===========================================================================
# Fig 4: CPI comparison across workloads (NEW - key figure)
# ===========================================================================
fig, ax = plt.subplots(figsize=(IEEE_WIDTH + 0.5, 3.5))
x = np.arange(3)

# 7 workloads - use horizontal bar chart for readability
workload_names = ["Compute", "Sort", "Dhrystone", "CM-insp.", "Diag.", "Branch", "CRC32"]
wdata = [bench_compute, bench_sort, dhrystone, coremark, diag, bench_branch, bench_crc32]
y = np.arange(len(workload_names))
h = 0.25

cpi_5 = [w["5-stage"]["CPI"] for w in wdata]
cpi_6 = [w["6-stage"]["CPI"] for w in wdata]
cpi_7 = [w["7-stage"]["CPI"] for w in wdata]

b1 = ax.barh(y + h, cpi_7, h, label="7-stage", color=colors[2], edgecolor="black", linewidth=0.4)
b2 = ax.barh(y,     cpi_6, h, label="6-stage", color=colors[1], edgecolor="black", linewidth=0.4)
b3 = ax.barh(y - h, cpi_5, h, label="5-stage", color=colors[0], edgecolor="black", linewidth=0.4)
for bars in [b1, b2, b3]:
    for bar in bars:
        w_val = bar.get_width()
        ax.text(w_val + 0.03, bar.get_y() + bar.get_height()/2,
                f"{w_val:.2f}", ha="left", va="center", fontsize=6)
ax.set_yticks(y)
ax.set_yticklabels(workload_names, fontsize=8)
ax.set_xlabel("CPI (cycles/instruction)")
ax.set_title("CPI Across Workloads")
ax.set_xlim(0, 3.2)
ax.legend(fontsize=7, loc="lower right")
fig.tight_layout()
save(fig, "cpi_comparison.png")

# ===========================================================================
# Fig 5: Throughput comparison
# ===========================================================================
fig, ax = plt.subplots(figsize=(IEEE_WIDTH, IEEE_HEIGHT))
mips = [synth[v]["Throughput_MIPS"] for v in variants]
bars = ax.bar(variants, mips, color=colors, edgecolor="black", linewidth=0.6, width=0.55)
bar_labels(ax, bars, fmt="{:.1f}", offset=1.0)
ax.set_ylabel("Throughput (MIPS)")
ax.set_title("Throughput ($F_{max}$ / CPI)")
ax.set_ylim(0, max(mips) * 1.18)
fig.tight_layout()
save(fig, "throughput_comparison.png")

# ===========================================================================
# Fig 6: Efficiency comparison
# ===========================================================================
fig, ax = plt.subplots(figsize=(IEEE_WIDTH, IEEE_HEIGHT))
eff = [synth[v]["Efficiency_MIPS_W"] for v in variants]
bars = ax.bar(variants, eff, color=colors, edgecolor="black", linewidth=0.6, width=0.55)
bar_labels(ax, bars, fmt="{:.1f}", offset=2.0)
ax.set_ylabel("MIPS / Watt")
ax.set_title("Energy Efficiency")
ax.set_ylim(0, max(eff) * 1.18)
fig.tight_layout()
save(fig, "efficiency_comparison.png")

# ===========================================================================
# Fig 7: Mispredict rate comparison (NEW - supports novelty claim)
# ===========================================================================
fig, ax = plt.subplots(figsize=(IEEE_WIDTH + 0.5, IEEE_HEIGHT))
wk_names = ["Sort", "Compute", "CM-insp.", "Branch", "CRC32"]
wk_data = [bench_sort, bench_compute, coremark, bench_branch, bench_crc32]
x = np.arange(len(wk_names))
w = 0.22

mr_5 = [d["5-stage"]["mispred_rate"] for d in wk_data]
mr_6 = [d["6-stage"]["mispred_rate"] for d in wk_data]
mr_7 = [d["7-stage"]["mispred_rate"] for d in wk_data]

b1 = ax.bar(x - w, mr_5, w, label="5-stage", color=colors[0], edgecolor="black", linewidth=0.5)
b2 = ax.bar(x,     mr_6, w, label="6-stage", color=colors[1], edgecolor="black", linewidth=0.5)
b3 = ax.bar(x + w, mr_7, w, label="7-stage", color=colors[2], edgecolor="black", linewidth=0.5)
bar_labels(ax, b1, fmt="{:.1f}%", offset=0.4, fs=6)
bar_labels(ax, b2, fmt="{:.1f}%", offset=0.4, fs=6)
bar_labels(ax, b3, fmt="{:.1f}%", offset=0.4, fs=6)
ax.set_xticks(x)
ax.set_xticklabels(wk_names, fontsize=8)
ax.set_ylabel("Misprediction Rate (%)")
ax.set_title("Branch Misprediction Rate by Workload")
ax.set_ylim(0, 42)
ax.legend(fontsize=7, loc="upper left")
fig.tight_layout()
save(fig, "mispred_comparison.png")

# ===========================================================================
# Fig 8: Published cores comparison
# ===========================================================================
cores = [
    ("CVA6\n(6-stage)",        80),
    ("Ours-5s\n(5-stage)",     78),
    ("Ours-7s\n(7-stage)",     115),
    ("Ours-6s\n(6-stage)",     121),
    ("Ibex\n(2-stage)",        150),
    ("VexRiscv\n(5-stage)",    200),
    ("PicoRV32\n(multi-cyc.)", 250),
    ("SERV\n(serial)",         300),
]
core_names = [c[0] for c in cores]
core_fmax  = [c[1] for c in cores]
core_colors = ["tab:blue" if "Ours" in n else "tab:gray" for n in core_names]

fig, ax = plt.subplots(figsize=(IEEE_WIDTH, 3.2))
y = np.arange(len(cores))
bars = ax.barh(y, core_fmax, color=core_colors, edgecolor="black", linewidth=0.6, height=0.6)
for bar in bars:
    w = bar.get_width()
    ax.text(w + 3, bar.get_y() + bar.get_height() / 2,
            f"{w:.0f}", ha="left", va="center", fontsize=FONT_SIZE - 2)
ax.set_yticks(y)
ax.set_yticklabels(core_names, fontsize=FONT_SIZE - 2)
ax.set_xlabel("$F_{max}$ (MHz)")
ax.set_title("Comparison with Published RISC-V Cores")
ax.set_xlim(0, max(core_fmax) * 1.18)
fig.tight_layout()
save(fig, "published_cores_comparison.png")

print("\nAll plots generated successfully.")
