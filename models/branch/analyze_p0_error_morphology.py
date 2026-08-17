#!/usr/bin/env python3
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path


def update(counters, valid, index, actual):
    if actual and counters[index] != 3:
        counters[index] += 1
    elif not actual and counters[index] != 0:
        counters[index] -= 1
    valid[index] = True


def analyze(path):
    data = json.loads(Path(path).read_text())
    counters, valid = [2] * 1023, [False] * 1023
    for event in data["predictor_warmup_updates"]:
        index = (int(event["pc"], 0) >> 2) & 0x3ff
        if index == 1023:
            raise ValueError("unsupported P0 warm-up index 1023")
        update(counters, valid, index, bool(event["actual_taken"]))
    lookups, predictions, updates = {}, {}, {}
    for event in data["predictor_timeline_observations"]:
        event_id, pc = int(event["event_id"]), int(event["pc"], 0)
        index = (pc >> 2) & 0x3ff
        if index == 1023:
            continue
        if event["kind"] == "lookup":
            lookups[event_id] = (valid[index], counters[index])
        elif event["kind"] == "prediction":
            lookup_valid, counter = lookups[event_id]
            predictions[event_id] = {
                "pc": pc, "prediction": bool(counter & 2) if lookup_valid else bool(event["fallback_sign"]),
                "valid": lookup_valid, "counter": counter,
            }
        elif event["kind"] == "update":
            updates[event_id] = bool(event["actual_taken"])
            update(counters, valid, index, bool(event["actual_taken"]))
    branches = defaultdict(list)
    for event_id in sorted(set(predictions) & set(updates)):
        record = predictions[event_id]
        record["actual"] = updates[event_id]
        branches[record["pc"]].append(record)
    total_errors = sum(record["prediction"] != record["actual"] for records in branches.values() for record in records)
    summary = []
    for pc, records in branches.items():
        outcomes = [record["actual"] for record in records]
        errors = [record for record in records if record["prediction"] != record["actual"]]
        prediction_actual = Counter(
            (record["prediction"], record["actual"]) for record in records
        )
        transitions = Counter(zip(outcomes, outcomes[1:]))
        runs, run_length, last = [], 0, None
        for outcome in outcomes:
            if outcome == last:
                run_length += 1
            else:
                if run_length:
                    runs.append(run_length)
                last, run_length = outcome, 1
        if run_length:
            runs.append(run_length)
        majority_errors = min(sum(outcomes), len(outcomes) - sum(outcomes))
        one_bit_errors = sum(outcomes[index] != outcomes[index - 1] for index in range(1, len(outcomes)))
        summary.append({
            "pc": f"0x{pc:016x}", "resolved_observations": len(records),
            "direction_errors": len(errors), "error_rate": len(errors) / len(records),
            "error_share": len(errors) / total_errors if total_errors else 0,
            "taken_count": sum(outcomes), "not_taken_count": len(outcomes) - sum(outcomes),
            "prediction_actual_counts": {
                f"{'T' if prediction else 'N'}->{'T' if actual else 'N'}": prediction_actual[(prediction, actual)]
                for prediction in (True, False) for actual in (True, False)
            },
            "transitions": {f"{'T' if a else 'N'}->{'T' if b else 'N'}": transitions[(a, b)] for a in (True, False) for b in (True, False)},
            "run_lengths": runs, "counter_before_errors": [record["counter"] for record in errors],
            "errors_follow_transition": sum(index > 0 and outcomes[index] != outcomes[index - 1] and records[index]["prediction"] != outcomes[index] for index in range(len(records))),
            "cold_invalid_errors": sum(not record["valid"] for record in errors),
            "warm_valid_errors": sum(record["valid"] for record in errors),
            "static_majority_errors": majority_errors, "one_bit_errors": one_bit_errors,
        })
    summary.sort(key=lambda row: (-row["direction_errors"], row["pc"]))
    thresholds, cumulative, cursor = {}, 0, 0
    for threshold in (0.5, 0.8, 0.9):
        while cursor < len(summary) and cumulative < threshold * total_errors:
            cumulative += summary[cursor]["direction_errors"]
            cursor += 1
        thresholds[str(int(threshold * 100))] = [row["pc"] for row in summary[:cursor]]
    return {"input": str(path), "workload": data["workload"], "total_resolved_direction_errors": total_errors,
            "branches": summary, "error_coverage_pc_sets": thresholds}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("json_files", nargs="+", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = {"p0_error_morphology": [analyze(path) for path in args.json_files]}
    text = json.dumps(report, indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
