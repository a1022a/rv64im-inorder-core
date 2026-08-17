#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

BITS = 10
DEPTH = 1 << BITS
IMPLEMENTED_ENTRIES = DEPTH - 1


def prediction_from_state(valid, counter, fallback_sign):
    return bool(counter & 0b10) if valid else fallback_sign


def replay(path):
    data = json.loads(Path(path).read_text())
    if data.get("schema_version") != "a2-raw-v4":
        raise ValueError(f"{path}: expected schema_version a2-raw-v4")
    timeline = data["predictor_timeline_observations"]
    counters = [2] * IMPLEMENTED_ENTRIES
    valid = [False] * IMPLEMENTED_ENTRIES
    lookups, predictions, updates = {}, {}, {}
    mismatches, lookup_state_mismatches = [], []
    unsupported = unsupported_warmup = 0
    warmup = data.get("predictor_warmup_updates", [])
    expected_sequence = 0
    for event in warmup:
        if int(event["sequence"]) != expected_sequence:
            raise ValueError(f"{path}: non-contiguous warm-up sequence")
        expected_sequence += 1
        pc = int(event["pc"], 0)
        index = (pc >> 2) & (DEPTH - 1)
        if index == IMPLEMENTED_ENTRIES:
            unsupported_warmup += 1
            continue
        if event["actual_taken"] and counters[index] != 3:
            counters[index] += 1
        elif not event["actual_taken"] and counters[index] != 0:
            counters[index] -= 1
        valid[index] = True
    for event in timeline:
        kind = event["kind"]
        event_id = int(event["event_id"])
        pc = int(event["pc"], 0)
        index = int(event["index"])
        if index != ((pc >> 2) & (DEPTH - 1)):
            raise ValueError(f"{path}: inconsistent predictor index for {event['pc']}")
        if index == IMPLEMENTED_ENTRIES:
            unsupported += 1
            continue
        if kind == "lookup":
            rtl_state = (bool(event["valid"]), int(event["counter"]))
            software_state = (valid[index], counters[index])
            if software_state != rtl_state:
                lookup_state_mismatches.append(event)
            lookups[event_id] = {"cycle": event["cycle"], "state": software_state}
        elif kind == "prediction":
            if event_id not in lookups:
                raise ValueError(f"{path}: prediction has no lookup id {event_id}")
            lookup = lookups[event_id]
            replay_prediction = prediction_from_state(
                lookup["state"][0], lookup["state"][1], bool(event["fallback_sign"])
            )
            rtl_prediction = bool(event["predicted_taken"])
            result = {"event_id": event_id, "cycle": event["cycle"], "pc": event["pc"],
                      "rtl_predicted_taken": rtl_prediction,
                      "replay_predicted_taken": replay_prediction,
                      "prediction_mismatch": replay_prediction != rtl_prediction}
            predictions[event_id] = result
            if result["prediction_mismatch"]:
                mismatches.append(result)
        elif kind == "update":
            updates[event_id] = {"pc": event["pc"], "index": index,
                                 "actual_taken": bool(event["actual_taken"])}
            if event["actual_taken"] and counters[index] != 3:
                counters[index] += 1
            elif not event["actual_taken"] and counters[index] != 0:
                counters[index] -= 1
            valid[index] = True
        else:
            raise ValueError(f"{path}: unknown predictor timeline kind {kind}")
    resolved_ids = sorted(set(predictions) & set(updates))
    unresolved_ids = sorted(set(predictions) - set(updates))
    carry_in_ids = sorted(set(updates) - set(predictions))
    resolved_errors = sum(predictions[i]["replay_predicted_taken"] != updates[i]["actual_taken"] for i in resolved_ids)
    carry_in_unknown = 0
    return {"input": str(path), "workload": data.get("workload"),
            "lookup_events": sum(e["kind"] == "lookup" for e in timeline),
            "prediction_events": len(predictions), "update_events": len(updates),
            "resolved_prediction_events": len(resolved_ids),
            "unresolved_prediction_events": len(unresolved_ids),
            "carry_in_update_events": len(carry_in_ids),
            "warmup_update_events": len(warmup),
            "unsupported_warmup_index_1023_events": unsupported_warmup,
            "carry_in_updates_without_known_pre_state": carry_in_unknown,
            "cold_fallback_oracle_events": 0,
            "unsupported_index_1023_events": unsupported,
            "lookup_state_mismatch_count": len(lookup_state_mismatches),
            "prediction_mismatch_count": len(mismatches),
            "prediction_mismatch_percentage": 100.0 * len(mismatches) / len(predictions) if predictions else 0.0,
            "resolved_replay_direction_error_count": resolved_errors,
            "rtl_conditional_direction_recovery_episodes": data.get("conditional_direction_recovery_episode_count"),
            "prediction_only_event_ids": unresolved_ids, "update_only_event_ids": carry_in_ids}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("json_files", nargs="+", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = {"p0_replay_results": [replay(path) for path in args.json_files]}
    text = json.dumps(report, indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
