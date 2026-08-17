#!/usr/bin/env python3
import csv
import json
import sys
from pathlib import Path


def ratio(numerator, denominator):
    return numerator / denominator if denominator else None


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: analyze_cache_profile.py OUTPUT.csv NAME=INPUT.json ...")
    rows = []
    for item in sys.argv[2:]:
        workload, filename = item.split("=", 1)
        data = json.loads(Path(filename).read_text())
        cycles = data["roi_cycles"]
        icache_accesses = data["icache_accesses"]
        dcache_accesses = data["dcache_accesses"]
        row = {"workload": workload, "roi_cycles": cycles,
               "retired_instructions": "NOT_QUALIFIED", "ipc": "NOT_QUALIFIED"}
        row.update(data)
        row.update({
            "icache_miss_rate": ratio(data["icache_misses"], icache_accesses),
            "icache_mpki": "NOT_QUALIFIED",
            "icache_stall_fraction": ratio(data["icache_total_stall_cycles"], cycles),
            "dcache_miss_rate": ratio(data["dcache_misses"], dcache_accesses),
            "dcache_mpki": "NOT_QUALIFIED",
            "dcache_stall_fraction": ratio(data["dcache_total_stall_cycles"], cycles),
            "checksum/status": data.get("checksum", "PASS"),
        })
        rows.append(row)
    fields = ["workload", "roi_cycles", "retired_instructions", "ipc",
              "icache_accesses", "icache_hits", "icache_misses", "icache_miss_rate",
              "icache_mpki", "icache_refill_completed_in_roi", "icache_miss_allocated_in_roi",
              "icache_miss_stall_cycles", "icache_stall_fraction", "dcache_accesses",
              "dcache_load_accesses", "dcache_store_accesses", "dcache_hits", "dcache_misses",
              "dcache_miss_rate", "dcache_mpki", "dcache_load_hits", "dcache_load_misses",
              "dcache_store_hits", "dcache_store_misses", "dcache_refill_completed_in_roi",
              "dcache_dirty_evictions", "dcache_writeback_completed_in_roi",
              "dcache_miss_stall_cycles", "dcache_writeback_stall_cycles",
              "dcache_total_stall_cycles", "dcache_stall_fraction", "exclusive_branch_cycles",
              "exclusive_dependency_cycles", "exclusive_icache_cycles", "exclusive_dcache_cycles",
              "exclusive_other_cycles", "checksum/status"]
    with Path(sys.argv[1]).open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
