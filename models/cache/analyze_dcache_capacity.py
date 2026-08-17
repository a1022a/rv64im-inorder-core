#!/usr/bin/env python3
import argparse
import csv
import json
from pathlib import Path


BASELINES = {
    "FIB": {"cycles": 11978, "misses": 0, "stall": 0},
    "BUBBLE": {"cycles": 1860, "misses": 3, "stall": 26},
    "GOL128": {"cycles": 590363, "misses": 1016, "stall": 17280},
    "GOL256": {"cycles": 2394963, "misses": 4080, "stall": 69368},
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("dse_csv")
    parser.add_argument("output_json")
    args = parser.parse_args()
    rows = list(csv.DictReader(Path(args.dse_csv).open(newline="")))
    analysis = {"schema_version": "a2-cache-c2-counterfactual-v1",
                "assumption": "ASSUMES_SIMILAR_MISS_WRITEBACK_PENALTY",
                "workloads": {}}
    for workload, baseline in BASELINES.items():
        variants = {}
        perfect_d_speedup = (baseline["cycles"] / (baseline["cycles"] - baseline["stall"])
                             if baseline["stall"] else 1.0)
        for row in rows:
            if row["workload"] != workload:
                continue
            capacity = int(row["capacity_kib"])
            misses = int(row["misses"])
            if baseline["misses"]:
                estimated_stall = baseline["stall"] * misses / baseline["misses"]
            else:
                estimated_stall = 0.0
            estimated_cycles = baseline["cycles"] - baseline["stall"] + estimated_stall
            speedup = baseline["cycles"] / estimated_cycles
            if speedup > perfect_d_speedup + 1e-12:
                raise ValueError(f"{workload} {capacity} KiB exceeds perfect-D$ bound")
            variants[str(capacity)] = {
                "misses": misses,
                "estimated_dcache_stall_cycles": estimated_stall,
                "counterfactual_estimated_cycles": estimated_cycles,
                "counterfactual_estimated_speedup": speedup,
                "estimated_required_mhz_at_180gps": estimated_cycles * 180 / 1_000_000,
                "status": "MEASURED_BASELINE" if capacity == 8 else
                          "COUNTERFACTUAL_ESTIMATE_ONLY",
            }
        analysis["workloads"][workload] = {
            "baseline_roi_cycles": baseline["cycles"],
            "baseline_dcache_misses": baseline["misses"],
            "baseline_dcache_stall_cycles": baseline["stall"],
            "measured_average_dcache_stall_per_baseline_miss":
                baseline["stall"] / baseline["misses"] if baseline["misses"] else None,
            "perfect_dcache_upper_bound_speedup": perfect_d_speedup,
            "variants": variants,
        }
    Path(args.output_json).write_text(json.dumps(analysis, indent=2) + "\n")


if __name__ == "__main__":
    main()
