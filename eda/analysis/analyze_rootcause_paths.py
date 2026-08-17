import csv
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(r"C:/testshare")


def family(sp: str, ep: str) -> str:
    if "u_rv64im_core_icache/plru_arry_reg" in ep:
        if "reg_alu_op_info" in sp:
            return "ID_ALU_OP_TO_ICACHE_PLRU"
        if "reg_alu_type_info" in sp:
            return "ID_ALU_TYPE_TO_ICACHE_PLRU"
        return "CONTROL_TO_ICACHE_PLRU"
    if "u_rv64im_core_div" in sp and "u_rv64im_core_id_alu" in ep:
        return "DIV_RESULT_TO_ID_ALU_OPERAND"
    if "u_rv64im_core_div" in sp and "u_rv64im_core_div" in ep:
        return "DIV_INTERNAL"
    if "u_rv64im_core_csr_reg/cycle_reg" in sp and "u_rv64im_core_csr_reg/cycle_reg" in ep:
        return "CSR_CYCLE_COUNTER"
    if "u_rv64im_core_clint/reg_mtime" in sp and "u_rv64im_core_clint/reg_mtime" in ep:
        return "CLINT_MTIME_COUNTER"
    if "u_rv64im_core_id_alu" in sp and "u_rv64im_core_id_alu" in ep:
        return "ID_ALU_INTERNAL"
    if "u_rv64im_core_id_alu" in sp and "u_rv64im_core_div" in ep:
        return "ID_ALU_OPERAND_TO_DIV"
    if "u_rv64im_core_id_alu" in sp and "u_rv64im_core_alu" in ep:
        return "ID_ALU_OPERAND_TO_ALU"
    if "reg_mul_cas" in ep and "reg_alu_type_info" in sp:
        return "MUL_CONTROL_TO_LSU_PRODUCT_PIPE"
    if "reg_mul_cas" in ep and "reg_id_alu_rs" in sp:
        return "ID_ALU_OPERAND_TO_LSU_PRODUCT_PIPE"
    if "u_rv64im_core_satcnt" in ep and "reg_alu_type_info" in sp:
        return "BRANCH_CONTROL_TO_IFU_PREDICTOR"
    if "u_rv64im_core_lsu" in sp and "u_rv64im_core_id_alu" in ep:
        return "LSU_TO_ID_ALU"
    return "OTHER_INTERNAL"


def module_of(name: str) -> str:
    for token in [
        "u_rv64im_core_div", "u_rv64im_core_id_alu", "u_rv64im_core_alu",
        "u_rv64im_core_csr_reg", "u_rv64im_core_icache", "u_rv64im_core_lsu",
        "u_rv64im_core_clint", "u_rv64im_core_dcache", "u_rv64im_core_regfile",
    ]:
        if token in name:
            return token.removeprefix("u_")
    return name.split("/")[0]


def load(tag: str):
    with (ROOT / f"{tag}_paths.csv").open(newline="") as f:
        paths = list(csv.DictReader(f))
    with (ROOT / f"{tag}_path_points.csv").open(newline="") as f:
        points = list(csv.DictReader(f))
    with (ROOT / f"{tag}_path_nets.csv").open(newline="") as f:
        nets = list(csv.DictReader(f))
    by_path = defaultdict(list)
    for p in points:
        by_path[int(p["path_index"])].append(p)
    nets_by_path = defaultdict(list)
    for n in nets:
        nets_by_path[int(n["path_index"])].append(n)

    rows = []
    for path in paths:
        idx = int(path["path_index"])
        pts = sorted(by_path[idx], key=lambda x: int(x["point_index"]))
        cell_delay = 0.0
        net_delay = 0.0
        output_refs = []
        increments = []
        previous_arrival = None
        for point in pts:
            arrival = float(point["arrival_ns"])
            if previous_arrival is not None:
                inc = max(0.0, arrival - previous_arrival)
                if point["direction"] == "out":
                    cell_delay += inc
                    output_refs.append(point["ref_name"])
                    increments.append((inc, point["object"], point["ref_name"]))
                elif point["direction"] == "in":
                    net_delay += inc
            previous_arrival = arrival
        # output_refs[0] is launch Q / clk-to-Q, not combinational logic.
        comb_refs = output_refs[1:] if output_refs else []
        mux_depth = sum(1 for ref in comb_refs if "MUX" in ref.upper())
        max_fanout = max((int(n["fanout"]) for n in nets_by_path[idx]), default=0)
        high_fanout = sorted(
            ((int(n["fanout"]), n["net"], n["driver"]) for n in nets_by_path[idx]),
            reverse=True,
        )[:5]
        total = cell_delay + net_delay
        fam = family(path["startpoint"], path["endpoint"])
        rows.append({
            **path,
            "family": fam,
            "source_module": module_of(path["startpoint"]),
            "destination_module": module_of(path["endpoint"]),
            "data_path_delay_ns": f"{total:.6f}",
            "cell_delay_ns": f"{cell_delay:.6f}",
            "net_delay_ns": f"{net_delay:.6f}",
            "cell_delay_percent": f"{(100*cell_delay/total if total else 0):.2f}",
            "net_delay_percent": f"{(100*net_delay/total if total else 0):.2f}",
            "logic_depth": len(comb_refs),
            "mux_depth": mux_depth,
            "max_path_net_fanout": max_fanout,
            "largest_incremental_cells": ";".join(
                f"{obj}:{ref}:{inc:.6f}" for inc, obj, ref in sorted(increments, reverse=True)[:5]
            ),
            "highest_fanout_nets": ";".join(
                f"{net}:{fo}:{drv}" for fo, net, drv in high_fanout
            ),
            "cell_ref_histogram": ";".join(f"{k}:{v}" for k, v in Counter(comb_refs).most_common()),
        })
    return rows


all_rows = []
for tag in ("p1p35", "p1p30"):
    rows = load(tag)
    all_rows.extend(rows)
    fields = list(rows[0].keys())
    with (ROOT / f"{tag}_derived_path_metrics.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    groups = defaultdict(list)
    for row in rows:
        groups[row["family"]].append(row)
    print(f"[{tag}] count={len(rows)}")
    for fam, members in sorted(groups.items(), key=lambda kv: (-len(kv[1]), min(float(x["slack_ns"]) for x in kv[1]))):
        worst = min(members, key=lambda x: float(x["slack_ns"]))
        print(
            f"{fam}|count={len(members)}|pct={100*len(members)/len(rows):.2f}|"
            f"worst={worst['slack_ns']}|idx={worst['path_index']}|"
            f"depth={worst['logic_depth']}|mux={worst['mux_depth']}|"
            f"cell%={worst['cell_delay_percent']}|net%={worst['net_delay_percent']}|"
            f"start={worst['startpoint']}|end={worst['endpoint']}"
        )

print("[TOP_ROWS]")
for row in all_rows:
    if row["path_index"] == "1" or row["family"] in {
        "DIV_RESULT_TO_ID_ALU_OPERAND", "ID_ALU_OP_TO_ICACHE_PLRU",
        "ID_ALU_TYPE_TO_ICACHE_PLRU", "DIV_INTERNAL", "CSR_CYCLE_COUNTER",
        "CLINT_MTIME_COUNTER", "ID_ALU_INTERNAL", "ID_ALU_OPERAND_TO_DIV",
    }:
        print(
            f"{row['point_tag']}#{row['path_index']} {row['family']} slack={row['slack_ns']} "
            f"delay={row['data_path_delay_ns']} cell={row['cell_delay_percent']}% net={row['net_delay_percent']}% "
            f"depth={row['logic_depth']} mux={row['mux_depth']} maxfo={row['max_path_net_fanout']}"
        )
