#!/usr/bin/env python3
"""
ppa_sweep.py — PPA sweep for async_fifo across LibreLane configs.
Usage (from inside the nix-shell, from project root):
    python3 pnr/ppa_sweep.py
"""

import subprocess, re, os, csv, yaml
from pathlib import Path

SWEEPS = [
    {"label": "baseline",       "CLOCK_PERIOD": 10, "FP_CORE_UTIL": 40, "PL_TARGET_DENSITY_PCT": 45},
    {"label": "faster_clk",     "CLOCK_PERIOD":  8, "FP_CORE_UTIL": 40, "PL_TARGET_DENSITY_PCT": 45},
    {"label": "high_util",      "CLOCK_PERIOD": 10, "FP_CORE_UTIL": 60, "PL_TARGET_DENSITY_PCT": 65},
    {"label": "high_util_fast", "CLOCK_PERIOD":  8, "FP_CORE_UTIL": 60, "PL_TARGET_DENSITY_PCT": 65},
    {"label": "relaxed_clk",    "CLOCK_PERIOD": 15, "FP_CORE_UTIL": 50, "PL_TARGET_DENSITY_PCT": 55},
]

# Absolute paths — resolved once here, written into every sweep config
SCRIPT_DIR  = Path(__file__).resolve().parent        # .../pnr/
PROJECT_DIR = SCRIPT_DIR.parent                       # .../async_fifo_project/
RTL_DIR     = PROJECT_DIR / "rtl"
SWEEP_DIR   = SCRIPT_DIR / "sweep_configs"
RESULTS_CSV = PROJECT_DIR / "results" / "ppa_results.csv"
PDK_ROOT    = Path.home() / ".ciel"

SWEEP_DIR.mkdir(exist_ok=True)

def write_config(label, overrides):
    """Write a sweep config with absolute paths so location doesn't matter."""
    cfg = {
        "DESIGN_NAME": "async_fifo",
        # Absolute paths — no dir:: needed
        "VERILOG_FILES": [
            str(RTL_DIR / "bin2gray.v"),
            str(RTL_DIR / "sync_2ff.v"),
            str(RTL_DIR / "wptr_full.v"),
            str(RTL_DIR / "rptr_empty.v"),
            str(RTL_DIR / "dualport_ram.v"),
            str(RTL_DIR / "async_fifo.v"),
        ],
        "CLOCK_PORT":     "wr_clk",
        "CLOCK_PERIOD":   overrides["CLOCK_PERIOD"],
        "PNR_SDC_FILE":   str(SCRIPT_DIR / "async_fifo_cdc.sdc"),
        "FP_SIZING":      "relative",
        "FP_CORE_UTIL":   overrides["FP_CORE_UTIL"],
        "FP_ASPECT_RATIO": 1,
        "PL_TARGET_DENSITY_PCT": overrides["PL_TARGET_DENSITY_PCT"],
        "DRT_THREADS":    4,
    }
    out = SWEEP_DIR / f"config_{label}.yaml"
    with open(out, "w") as f:
        yaml.dump(cfg, f, default_flow_style=False)
    return out

def run_librelane(config_path, label):
    print(f"\n{'='*60}\n  Running: {label}\n{'='*60}")
    result = subprocess.run(
        ["python3", "-m", "librelane", "--pdk-root", str(PDK_ROOT), str(config_path)],
        text=True
    )
    return result.returncode == 0

def find_latest_run():
    runs = sorted(PROJECT_DIR.glob("**/runs/RUN_*"), key=lambda p: p.stat().st_mtime)
    return runs[-1] if runs else None

def grep(path, pattern):
    try:
        for line in Path(path).read_text().splitlines():
            m = re.search(pattern, line, re.IGNORECASE)
            if m: return m
    except Exception:
        pass
    return None

def parse_wns(run_dir):
    for f in sorted(run_dir.glob("**/sta.log"), key=lambda p: p.stat().st_mtime, reverse=True):
        m = grep(f, r'wns\s*[=:]\s*(-?[\d.]+)')
        if m: return float(m.group(1))
    return None

def parse_area(run_dir):
    for f in sorted(run_dir.glob("**/yosys-synthesis.log"), key=lambda p: p.stat().st_mtime, reverse=True):
        m = grep(f, r'Chip area[^:]*:\s*([\d.]+)')
        if m: return float(m.group(1))
    return None

def parse_power(run_dir):
    for f in sorted(run_dir.glob("**/openroad-irdropreport.log"), key=lambda p: p.stat().st_mtime, reverse=True):
        m = grep(f, r'Total power\s*[:\s]+([\d.e+\-]+)')
        if m: return float(m.group(1))
    return None

def main():
    results = []
    for sweep in SWEEPS:
        label   = sweep["label"]
        config  = write_config(label, sweep)
        success = run_librelane(config, label)
        run_dir = find_latest_run()

        row = {
            "label":        label,
            "clock_period": sweep["CLOCK_PERIOD"],
            "util":         sweep["FP_CORE_UTIL"],
            "density":      sweep["PL_TARGET_DENSITY_PCT"],
            "status":       "PASS" if success else "FAIL",
            "wns_ns":       None,
            "area_um2":     None,
            "power_W":      None,
        }
        if success and run_dir:
            row["wns_ns"]   = parse_wns(run_dir)
            row["area_um2"] = parse_area(run_dir)
            row["power_W"]  = parse_power(run_dir)

        results.append(row)

    print("\n" + "="*80)
    print("PPA SWEEP RESULTS — async_fifo / SKY130B")
    print("="*80)
    print(f"{'Label':<20} {'Tclk':>6} {'Util':>5} {'Status':>6} {'WNS(ns)':>9} {'Area(um2)':>10} {'Pwr(W)':>9}")
    print("-"*80)
    for r in results:
        print(f"{r['label']:<20} {r['clock_period']:>6} {r['util']:>5} {r['status']:>6} "
              f"{str(r['wns_ns'] or 'N/A'):>9} {str(r['area_um2'] or 'N/A'):>10} {str(r['power_W'] or 'N/A'):>9}")
    print("="*80)

    with open(RESULTS_CSV, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=results[0].keys())
        w.writeheader()
        w.writerows(results)
    print(f"\nResults saved to: {RESULTS_CSV}")

if __name__ == "__main__":
    main()
