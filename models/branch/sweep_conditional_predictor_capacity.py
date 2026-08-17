#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


CONFIGURATIONS = (512, 1024, 2048)
FROZEN_WORKLOADS = {
    "microbench_fib": {"p0_errors": 603, "p0_cycles": 11978},
    "cpu_bubble_sort": {"p0_errors": 104, "p0_cycles": 1860},
}


def index_for(pc, entries):
    return (pc >> 2) & (entries - 1)


def update(counters, valid, index, actual_taken):
    if actual_taken and counters[index] != 3:
        counters[index] += 1
    elif not actual_taken and counters[index] != 0:
        counters[index] -= 1
    valid[index] = True


def replay_candidate(data, entries):
    counters = [2] * (entries - 1)
    valid = [False] * (entries - 1)
    warmup_last_index = 0
    roi_last_index_lookups = 0
    roi_last_index_predictions = 0
    roi_last_index_updates = 0
    for event in data.get("predictor_warmup_updates", []):
        index = index_for(int(event["pc"], 0), entries)
        if index == entries - 1:
            warmup_last_index += 1
            continue
        update(counters, valid, index, bool(event["actual_taken"]))

    timeline = data["predictor_timeline_observations"]
    predictions = {}
    updates = {}
    lookups = {}
    for event in timeline:
        event_id = int(event["event_id"])
        pc = int(event["pc"], 0)
        index = index_for(pc, entries)
        if index == entries - 1:
            if event["kind"] == "lookup":
                roi_last_index_lookups += 1
            elif event["kind"] == "prediction":
                roi_last_index_predictions += 1
            elif event["kind"] == "update":
                roi_last_index_updates += 1
            continue
        if event["kind"] == "lookup":
            lookups[event_id] = (valid[index], counters[index])
        elif event["kind"] == "prediction":
            if event_id not in lookups:
                raise ValueError(f"prediction without lookup: {event_id}")
            lookup_valid, lookup_counter = lookups[event_id]
            prediction = bool(lookup_counter & 2) if lookup_valid else bool(event["fallback_sign"])
            predictions[event_id] = prediction
        elif event["kind"] == "update":
            updates[event_id] = bool(event["actual_taken"])
            update(counters, valid, index, bool(event["actual_taken"]))

    resolved_ids = sorted(set(predictions) & set(updates))
    errors = sum(predictions[event_id] != updates[event_id] for event_id in resolved_ids)
    return {
        "table_entries": entries,
        "counter_bits": 2,
        "nominal_predictor_state_bits": entries * 3,
        "warmup_update_count": len(data.get("predictor_warmup_updates", [])),
        "unsupported_last_index_warmup_updates": warmup_last_index,
        "roi_resolved_conditional_events_modeled": len(resolved_ids),
        "unsupported_last_index_roi_lookups": roi_last_index_lookups,
        "unsupported_last_index_roi_predictions": roi_last_index_predictions,
        "unsupported_last_index_roi_updates": roi_last_index_updates,
        "modeled_resolved_direction_error_count": errors,
        "candidate_supported": (
            warmup_last_index == 0 and roi_last_index_lookups == 0 and
            roi_last_index_predictions == 0 and roi_last_index_updates == 0
        ),
    }


def analyze(path):
    data = json.loads(Path(path).read_text())
    if data.get("schema_version") != "a2-raw-v4":
        raise ValueError(f"{path}: expected a2-raw-v4")
    if data["workload"] not in FROZEN_WORKLOADS:
        raise ValueError(f"{path}: unsupported frozen workload {data['workload']}")
    baseline = FROZEN_WORKLOADS[data["workload"]]
    p0_errors = baseline["p0_errors"]
    p0_cycles = baseline["p0_cycles"]
    results = []
    for entries in CONFIGURATIONS:
        result = replay_candidate(data, entries)
        if entries == 1024 and result["modeled_resolved_direction_error_count"] != p0_errors:
            raise ValueError(f"{path}: 1024-entry P0 replay does not match frozen baseline")
        reduction = p0_errors - result["modeled_resolved_direction_error_count"]
        result["delta_direction_errors_vs_p0"] = result["modeled_resolved_direction_error_count"] - p0_errors
        result["direction_error_reduction_percentage_vs_p0"] = 100.0 * reduction / p0_errors
        result["model_estimated_roi_cycles"] = p0_cycles - reduction
        result["model_estimated_cycle_reduction"] = reduction
        result["model_estimated_cycle_speedup"] = p0_cycles / result["model_estimated_roi_cycles"]
        result["minimum_fmax_retention_ratio"] = result["model_estimated_roi_cycles"] / p0_cycles
        result["maximum_tolerable_fmax_loss_percentage"] = 100.0 * (1.0 - result["minimum_fmax_retention_ratio"])
        results.append(result)
    return {"input": str(path), "workload": data["workload"], "p0_roi_cycles": p0_cycles,
            "p0_resolved_direction_errors": p0_errors, "configurations": results}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("json_files", nargs="+", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = {"capacity_sweep_results": [analyze(path) for path in args.json_files]}
    text = json.dumps(report, indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
