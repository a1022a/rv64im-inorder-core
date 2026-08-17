#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path

from replay_dcache import replay_trace


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output")
    parser.add_argument("traces", nargs="+", metavar="WORKLOAD=TRACE")
    args = parser.parse_args()
    rows = []
    for item in args.traces:
        workload, trace = item.split("=", 1)
        results = {capacity: replay_trace(trace, capacity * 1024)
                   for capacity in (4, 8, 16, 32)}
        baseline_misses = results[8]["roi"]["misses"]
        for capacity, result in results.items():
            roi = result["roi"]
            miss_delta = roi["misses"] - baseline_misses
            reduction = ((baseline_misses - roi["misses"]) / baseline_misses * 100
                         if baseline_misses else 0.0)
            rows.append({
                "workload": workload,
                "capacity_kib": capacity,
                "sets": result["sets"],
                "ways": result["ways"],
                "line_bytes": result["line_bytes"],
                "roi_accesses": roi["accesses"],
                "load_accesses": roi["load_accesses"],
                "store_accesses": roi["store_accesses"],
                "hits": roi["hits"],
                "misses": roi["misses"],
                "miss_rate": roi["misses"] / roi["accesses"] if roi["accesses"] else 0,
                "dirty_evictions": roi["dirty_evictions"],
                "writebacks": roi["writebacks"],
                "miss_delta_vs_8k": miss_delta,
                "miss_reduction_percent_vs_8k": reduction,
            })
    if not rows:
        raise ValueError("at least one trace is required")
    fields = list(rows[0])
    with Path(args.output).open("w", newline="") as output:
        writer = csv.DictWriter(output, fields)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
