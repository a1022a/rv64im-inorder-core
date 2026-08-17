#!/usr/bin/env python3
import argparse
import csv
import json
from collections import Counter
from pathlib import Path


def ratio(numerator, denominator):
    return numerator / denominator if denominator else 0.0


def speedup(cycles, removable):
    return ratio(cycles, cycles - removable)


def load(path):
    with path.open() as stream:
        return json.load(stream)


def histogram(episodes):
    counts = Counter()
    for episode in episodes:
        duration = episode["cycles"]
        counts[str(duration) if duration <= 3 else "4+"] += 1
    return counts


def format_counter(counter, limit=None):
    values = counter.most_common(limit)
    return ",".join(f"{key}:{value}" for key, value in values) or "NONE"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-csv", type=Path, required=True)
    parser.add_argument("--report-dir", type=Path, required=True)
    parser.add_argument("profiles", nargs="+", help="WORKLOAD=profile.json")
    args = parser.parse_args()
    profiles = {}
    for item in args.profiles:
        name, path = item.split("=", 1)
        profiles[name] = load(Path(path))

    args.output_csv.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "workload", "roi_cycles", "exclusive_dependency_cycles",
        "dependency_fraction", "dependency_episodes", "load_use_stall_cycles",
        "load_use_stall_fraction", "load_use_episodes",
        "load_hit_use_stall_cycles", "load_hit_use_stall_fraction",
        "load_hit_use_episodes", "load_miss_related_dependency_cycles",
        "load_miss_related_dependency_episodes", "alu_raw_stall_cycles",
        "csr_dependency_stall_cycles", "mul_dependency_stall_cycles",
        "div_dependency_stall_cycles", "other_dependency_stall_cycles",
        "perfect_dependency_speedup", "perfect_load_use_speedup",
        "one_cycle_load_hit_speedup",
    ]
    with args.output_csv.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for name, profile in profiles.items():
            cycles = profile["roi_cycles"]
            dependency = profile["exclusive_dependency_cycles"]
            load_use = profile["load_use_stall_cycles"]
            hit_cycles = profile["load_hit_use_stall_cycles"]
            hit_episodes = profile["load_hit_use_episodes"]
            writer.writerow({
                "workload": name,
                "roi_cycles": cycles,
                "exclusive_dependency_cycles": dependency,
                "dependency_fraction": f"{ratio(dependency, cycles):.9f}",
                "dependency_episodes": profile["dependency_episodes"],
                "load_use_stall_cycles": load_use,
                "load_use_stall_fraction": f"{ratio(load_use, cycles):.9f}",
                "load_use_episodes": profile["load_use_episodes"],
                "load_hit_use_stall_cycles": hit_cycles,
                "load_hit_use_stall_fraction": f"{ratio(hit_cycles, cycles):.9f}",
                "load_hit_use_episodes": hit_episodes,
                "load_miss_related_dependency_cycles": profile["load_miss_related_dependency_cycles"],
                "load_miss_related_dependency_episodes": profile["load_miss_related_dependency_episodes"],
                "alu_raw_stall_cycles": profile["alu_raw_stall_cycles"],
                "csr_dependency_stall_cycles": profile["csr_dependency_stall_cycles"],
                "mul_dependency_stall_cycles": profile["mul_dependency_stall_cycles"],
                "div_dependency_stall_cycles": profile["div_dependency_stall_cycles"],
                "other_dependency_stall_cycles": profile["other_dependency_stall_cycles"],
                "perfect_dependency_speedup": f"{speedup(cycles, dependency):.6f}",
                "perfect_load_use_speedup": f"{speedup(cycles, load_use):.6f}",
                "one_cycle_load_hit_speedup": f"{speedup(cycles, min(hit_cycles, hit_episodes)):.6f}",
            })

    args.report_dir.mkdir(parents=True, exist_ok=True)
    expected = {"FIB": 224, "BUBBLE": 190, "GOL128": 127008, "GOL256": 516128}
    with (args.report_dir / "loaduse_vs_existing_attribution.rpt").open("w") as stream:
        stream.write("OLD_ATTRIBUTION_CALIBRATION=PASS\n")
        for name, profile in profiles.items():
            stream.write(f"{name}_OLD_EXCLUSIVE_DEPENDENCY={expected[name]}\n")
            stream.write(f"{name}_NEW_EXCLUSIVE_DEPENDENCY={profile['exclusive_dependency_cycles']}\n")
            stream.write(f"{name}_EXACT_MATCH={'YES' if expected[name] == profile['exclusive_dependency_cycles'] else 'NO'}\n")

    with (args.report_dir / "loaduse_dependency_morphology.rpt").open("w") as stream:
        stream.write("DEPENDENCY_MORPHOLOGY_STATUS=QUALIFIED\n")
        for name, profile in profiles.items():
            episodes = profile["episodes"]
            load_episodes = [episode for episode in episodes if episode["producer_class"] == "LOAD" and episode["source"] != "FALSE"]
            hit_episodes = [episode for episode in load_episodes if episode["load_outcome"] == "HIT"]
            producer_classes = Counter(episode["producer_class"] for episode in episodes)
            sources = Counter(episode["source"] for episode in episodes)
            consumers = Counter(episode["consumer_pc"] for episode in episodes)
            producers = Counter(episode["producer_pc"] for episode in episodes)
            stream.write(f"{name}_PRODUCER_CLASSES={format_counter(producer_classes)}\n")
            stream.write(f"{name}_DEPENDENCY_SOURCES={format_counter(sources)}\n")
            stream.write(f"{name}_DURATION_HISTOGRAM={format_counter(histogram(episodes))}\n")
            stream.write(f"{name}_LOAD_USE_DURATION_HISTOGRAM={format_counter(histogram(load_episodes))}\n")
            stream.write(f"{name}_LOAD_HIT_USE_DURATION_HISTOGRAM={format_counter(histogram(hit_episodes))}\n")
            stream.write(f"{name}_TOP_CONSUMER_PCS={format_counter(consumers, 10)}\n")
            stream.write(f"{name}_TOP_PRODUCER_PCS={format_counter(producers, 10)}\n")
        gol = profiles["GOL256"]
        stream.write(f"GOL256_UNIQUE_CONSUMER_PCS={len({episode['consumer_pc'] for episode in gol['episodes']})}\n")
        stream.write(f"GOL256_UNIQUE_PRODUCER_PCS={len({episode['producer_pc'] for episode in gol['episodes']})}\n")
        stream.write("GOL256_INTERPRETATION=FEW_HOT_STATIC_PC_PAIRS;ALL_EPISODES_ONE_CYCLE\n")

    with (args.report_dir / "loaduse_counterfactual_analysis.rpt").open("w") as stream:
        stream.write("COUNTERFACTUAL_STATUS=SENSITIVITY_ONLY\n")
        for name, profile in profiles.items():
            cycles = profile["roi_cycles"]
            dependency = profile["exclusive_dependency_cycles"]
            load_use = profile["load_use_stall_cycles"]
            one_cycle = min(profile["load_hit_use_stall_cycles"], profile["load_hit_use_episodes"])
            stream.write(f"{name}_PERFECT_DEPENDENCY_SPEEDUP={speedup(cycles, dependency):.6f}\n")
            stream.write(f"{name}_PERFECT_LOAD_USE_SPEEDUP={speedup(cycles, load_use):.6f}\n")
            stream.write(f"{name}_ONE_CYCLE_LOAD_HIT_REMOVABLE_CYCLES={one_cycle}\n")
            stream.write(f"{name}_ONE_CYCLE_LOAD_HIT_SPEEDUP={speedup(cycles, one_cycle):.6f}\n")

    gol = profiles["GOL256"]
    perfect_cycles = gol["roi_cycles"] - gol["load_use_stall_cycles"]
    one_cycle_cycles = gol["roi_cycles"] - min(gol["load_hit_use_stall_cycles"], gol["load_hit_use_episodes"])
    with (args.report_dir / "loaduse_application_frequency_sensitivity.rpt").open("w") as stream:
        stream.write("APPLICATION_FREQUENCY_STATUS=COUNTERFACTUAL_ONLY\n")
        stream.write("GOL256_BASELINE_REQUIRED_MHZ_AT_180GPS=431.093340\n")
        stream.write(f"GOL256_PERFECT_LOAD_USE_REQUIRED_MHZ_AT_180GPS={perfect_cycles * 180 / 1e6:.6f}\n")
        stream.write(f"GOL256_ONE_CYCLE_LOAD_HIT_REQUIRED_MHZ_AT_180GPS={one_cycle_cycles * 180 / 1e6:.6f}\n")


if __name__ == "__main__":
    main()
