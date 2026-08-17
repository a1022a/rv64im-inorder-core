#!/usr/bin/env python3
import argparse
import csv
import json
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass
class Way:
    valid: bool = False
    tag: int = 0
    dirty: bool = False


@dataclass
class ReplayCounts:
    accesses: int = 0
    load_accesses: int = 0
    store_accesses: int = 0
    hits: int = 0
    misses: int = 0
    dirty_evictions: int = 0
    writebacks: int = 0


class DCache:
    def __init__(self, capacity_bytes, ways=4, line_bytes=32):
        if ways != 4:
            raise ValueError("the qualified RTL replacement model requires four ways")
        if capacity_bytes <= 0 or capacity_bytes % (ways * line_bytes):
            raise ValueError("capacity must be divisible by ways * line_bytes")
        self.ways = ways
        self.line_bytes = line_bytes
        self.sets = capacity_bytes // (ways * line_bytes)
        if self.sets & (self.sets - 1):
            raise ValueError("set count must be a power of two")
        self.lines = [[Way() for _ in range(ways)] for _ in range(self.sets)]
        self.plru = [0] * self.sets

    @staticmethod
    def victim(plru):
        bit0 = plru & 1
        bit1 = (plru >> 1) & 1
        bit2 = (plru >> 2) & 1
        if bit0:
            return 3 if bit2 else 2
        return 1 if bit1 else 0

    @staticmethod
    def update_plru(plru, way):
        bit1 = (plru >> 1) & 1
        bit2 = (plru >> 2) & 1
        if way == 3:
            return bit1 << 1
        if way == 2:
            return 4 | (bit1 << 1)
        if way == 1:
            return (bit2 << 2) | 1
        if way == 0:
            return (bit2 << 2) | 3
        raise ValueError(f"invalid way {way}")

    def access(self, address, operation):
        if address < 0 or address > 0xffffffff:
            raise ValueError(f"address outside 32-bit D-cache interface: {address:#x}")
        line_number = address // self.line_bytes
        set_index = line_number % self.sets
        tag = line_number // self.sets
        set_lines = self.lines[set_index]
        hit_way = next((index for index, line in enumerate(set_lines)
                        if line.valid and line.tag == tag), None)
        if hit_way is not None:
            if operation == "STORE":
                set_lines[hit_way].dirty = True
            self.plru[set_index] = self.update_plru(self.plru[set_index], hit_way)
            return True, False

        victim_way = self.victim(self.plru[set_index])
        victim = set_lines[victim_way]
        dirty_eviction = victim.valid and victim.dirty
        victim.valid = True
        victim.tag = tag
        if operation == "STORE":
            victim.dirty = True
        self.plru[set_index] = self.update_plru(self.plru[set_index], victim_way)
        return False, dirty_eviction


def replay_trace(trace_path, capacity_bytes, check_rtl=False):
    cache = DCache(capacity_bytes)
    pre_roi = ReplayCounts()
    roi = ReplayCounts()
    rtl_mismatches = []
    expected_sequence = 0
    last_cycle = -1
    seen_roi = False
    with Path(trace_path).open(newline="") as trace_file:
        reader = csv.DictReader(trace_file)
        required = {"sequence_number", "simulation_cycle", "phase", "address",
                    "operation", "wmask", "rtl_hit", "rtl_miss", "rtl_dirty_eviction"}
        if set(reader.fieldnames or ()) != required:
            raise ValueError(f"unexpected trace columns: {reader.fieldnames}")
        for row in reader:
            sequence = int(row["sequence_number"])
            cycle = int(row["simulation_cycle"])
            phase = row["phase"]
            operation = row["operation"]
            address = int(row["address"], 0)
            if sequence != expected_sequence:
                raise ValueError(f"non-contiguous sequence at {sequence}")
            if cycle < last_cycle:
                raise ValueError(f"simulation cycle regressed at sequence {sequence}")
            if phase not in {"PRE_ROI", "ROI"}:
                raise ValueError(f"invalid phase {phase}")
            if phase == "ROI":
                seen_roi = True
            elif seen_roi:
                raise ValueError(f"PRE_ROI record after ROI at sequence {sequence}")
            if operation not in {"LOAD", "STORE"}:
                raise ValueError(f"invalid operation {operation}")
            wmask = int(row["wmask"], 0)
            if wmask < 0 or wmask > 0xff:
                raise ValueError(f"invalid access mask at sequence {sequence}")
            hit, dirty_eviction = cache.access(address, operation)
            counts = roi if phase == "ROI" else pre_roi
            counts.accesses += 1
            counts.load_accesses += operation == "LOAD"
            counts.store_accesses += operation == "STORE"
            counts.hits += hit
            counts.misses += not hit
            counts.dirty_evictions += dirty_eviction
            counts.writebacks += dirty_eviction
            if check_rtl:
                rtl_values = tuple(int(row[name]) for name in
                                   ("rtl_hit", "rtl_miss", "rtl_dirty_eviction"))
                if any(value not in {0, 1} for value in rtl_values):
                    raise ValueError(f"invalid RTL outcome at sequence {sequence}")
                if rtl_values[0] + rtl_values[1] != 1 or (rtl_values[2] and not rtl_values[1]):
                    raise ValueError(f"inconsistent RTL outcome at sequence {sequence}")
                rtl = tuple(bool(value) for value in rtl_values)
                replay = (hit, not hit, dirty_eviction)
                if rtl != replay and len(rtl_mismatches) < 20:
                    rtl_mismatches.append({"sequence": sequence, "phase": phase,
                                           "address": row["address"], "rtl": rtl,
                                           "replay": replay})
            expected_sequence += 1
            last_cycle = cycle
    if roi.accesses != roi.hits + roi.misses:
        raise AssertionError("ROI hit/miss invariant failed")
    return {
        "schema_version": "a2-cache-c2-replay-v1",
        "trace": str(Path(trace_path).resolve()),
        "capacity_bytes": capacity_bytes,
        "sets": cache.sets,
        "ways": cache.ways,
        "line_bytes": cache.line_bytes,
        "pre_roi": asdict(pre_roi),
        "roi": asdict(roi),
        "rtl_outcome_check": "PASS" if check_rtl and not rtl_mismatches else
                             "FAIL" if check_rtl else "NOT_REQUESTED",
        "rtl_mismatches": rtl_mismatches,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("trace")
    parser.add_argument("--capacity-kib", type=int, default=8)
    parser.add_argument("--check-rtl", action="store_true")
    parser.add_argument("--output")
    args = parser.parse_args()
    result = replay_trace(args.trace, args.capacity_kib * 1024, args.check_rtl)
    text = json.dumps(result, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(text)
    else:
        print(text, end="")
    if args.check_rtl and result["rtl_outcome_check"] != "PASS":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
