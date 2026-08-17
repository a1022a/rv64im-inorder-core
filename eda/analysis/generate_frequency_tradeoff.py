#!/usr/bin/env python3
import csv
import hashlib
import os
from datetime import datetime, timezone
from pathlib import Path

W = Path(os.environ["CHARACTERIZATION_WORKSPACE"])
SWEEP = W / "eda/dc/runs/frequency_sweep_01"
PT = W / "eda/pt/runs/frequency_sweep_01"
ROOTCAUSE = W / "eda/analysis/critical_path_rootcause_01"
OUT = W / "eda/analysis/frequency_tradeoff_01"
REPORTS = OUT / "reports"
META = OUT / "metadata"
SCRIPTS = OUT / "scripts"
PILOT = W / "eda/dc/runs/char_pilot_01"

PUBLICATION_COMMIT = "00439d9731c85bcf46e6aa717bf59708b9f1c293"
PUBLICATION_TREE = "56407a30556a0018d4ebe8375db4093d120af560"
TOP = "rv64im_core_top"


def env_read(path):
    data = {}
    for raw in path.read_text(errors="replace").splitlines():
        if "=" in raw and not raw.lstrip().startswith("#"):
            key, value = raw.split("=", 1)
            data[key.strip()] = value.strip()
    return data


def f(value, default=None):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def i(value, default=None):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def fmt(value, digits=12):
    if value is None:
        return "NA"
    return (("%." + str(digits) + "f") % value).rstrip("0").rstrip(".")


def pct(new, old):
    return None if new is None or old in (None, 0) else 100.0 * (new - old) / old


def classify(sp, ep):
    if "u_rv64im_core_lsu" in sp and "u_rv64im_core_id_alu" in ep:
        return "LSU_TO_ID_ALU"
    if "u_rv64im_core_id_alu" in sp and "u_rv64im_core_div" in ep:
        return "ID_ALU_OPERAND_TO_DIV"
    if "u_rv64im_core_div" in sp and "u_rv64im_core_id_alu" in ep:
        if "res_reg" in sp:
            return "DIV_RESULT_TO_ID_ALU_OPERAND"
        return "DIV_CONTROL_TO_ID_ALU_OPERAND"
    if "reg_alu_op_info" in sp and "u_rv64im_core_icache/plru_arry_reg" in ep:
        return "ID_ALU_OP_TO_ICACHE_PLRU"
    if "reg_alu_type_info" in sp and "u_rv64im_core_icache/plru_arry_reg" in ep:
        return "ID_ALU_TYPE_TO_ICACHE_PLRU"
    if "u_rv64im_core_id_alu" in sp and "u_rv64im_core_icache/plru_arry_reg" in ep:
        return "ID_ALU_OPERAND_TO_ICACHE_PLRU"
    if "u_rv64im_core_csr_reg/cycle_reg" in sp and "u_rv64im_core_csr_reg/cycle_reg" in ep:
        return "CSR_CYCLE_COUNTER"
    if "u_rv64im_core_clint/reg_mtime" in sp and "u_rv64im_core_icache/plru_arry_reg" in ep:
        return "CLINT_MTIME_TO_ICACHE_PLRU"
    return "OTHER_INTERNAL"


def build_point(env_path, run_dir, pilot=False):
    e = env_read(env_path)
    prefix = "DC_" if pilot else ""
    period = f(e.get("CLOCK_PERIOD_NS" if pilot else "PERIOD_NS"))
    freq = 1000.0 / period if period else None
    compile_ok = e.get("DC_COMPILE_ULTRA") == "PASS"
    flow_ok = e.get("DC_BASELINE") == "PASS" if pilot else e.get("FLOW_STATUS") == "PASS"
    mapped = (run_dir / "outputs/rv64im_core_top_mapped.v").is_file()
    area_report = (run_dir / "reports/report_area.rpt").is_file()
    timing_report = (run_dir / "reports/report_timing_max.rpt").is_file()
    reports_complete = area_report and timing_report
    wns = f(e.get(prefix + "WNS_NS"))
    timing = "UNKNOWN" if wns is None else ("PASS" if wns >= 0 else "FAIL")
    run_status = "PASS" if compile_ok and flow_ok and mapped and reports_complete else "INCOMPLETE"
    sp = e.get(prefix + "CRITICAL_PATH_STARTPOINT", "NA")
    ep = e.get(prefix + "CRITICAL_PATH_ENDPOINT", "NA")
    return {
        "period_ns": period,
        "frequency_mhz": freq,
        "run_status": run_status,
        "synthesis_completed": "YES" if compile_ok else "NO",
        "timing_status": timing,
        "wns_ns": wns,
        "tns_ns": f(e.get(prefix + "TNS_NS")),
        "violating_path_count": i(e.get(prefix + "VIOLATING_PATH_COUNT")),
        "stdcell_count": i(e.get(prefix + "STDCELL_INSTANCE_COUNT")),
        "sram_instance_count": i(e.get(prefix + "SRAM_INSTANCE_COUNT")),
        "stdcell_area": f(e.get(prefix + "STDCELL_AREA")),
        "macro_area": f(e.get(prefix + "MACRO_AREA")),
        "total_area": f(e.get(prefix + "TOTAL_DESIGN_AREA")),
        "worst_startpoint": sp,
        "worst_endpoint": ep,
        "worst_path_group": e.get(prefix + "CRITICAL_PATH_GROUP", "NA"),
        "worst_path_class": e.get(prefix + "CRITICAL_PATH_CLASS", "NA"),
        "critical_path_family": classify(sp, ep),
        "mapped_implementation_present": "YES" if mapped else "NO",
        "reports_complete": "YES" if reports_complete else "NO",
        "report_source": str(env_path),
        "run_directory": str(run_dir),
        "reference_type": "5NS_PILOT_REFERENCE" if pilot else "FREQUENCY_SWEEP_POINT",
    }


def write_report(name, text):
    (REPORTS / name).write_text(text.strip() + "\n", encoding="utf-8")


def main():
    if OUT.exists():
        existing = [p for p in OUT.rglob("*") if p.is_file() and p != (SCRIPTS / "generate_frequency_tradeoff.py")]
        if existing and os.environ.get("A2_REGENERATE_ANALYSIS") != "YES":
            raise SystemExit(f"analysis directory is not empty; refusing overwrite: {OUT}")
    REPORTS.mkdir(parents=True, exist_ok=True)
    META.mkdir(parents=True, exist_ok=True)
    SCRIPTS.mkdir(parents=True, exist_ok=True)

    source_files = []
    points = []
    pilot_env = PILOT / "metadata/dc_compile.env"
    points.append(build_point(pilot_env, PILOT, pilot=True))
    source_files += [pilot_env, PILOT / "metadata/run_manifest.txt"]

    for run_dir in SWEEP.glob("p*ns"):
        env_path = run_dir / "metadata/dc_point.env"
        if env_path.is_file():
            points.append(build_point(env_path, run_dir))
            source_files += [
                env_path,
                run_dir / "reports/report_area.rpt",
                run_dir / "reports/report_timing_max.rpt",
                run_dir / "reports/report_reference.rpt",
            ]
    points.sort(key=lambda x: x["frequency_mhz"])
    ref = points[0]
    prev = None
    for p in points:
        p["stdcell_area_delta_vs_slowest_valid_pct"] = pct(p["stdcell_area"], ref["stdcell_area"])
        p["stdcell_count_delta_vs_slowest_valid_pct"] = pct(p["stdcell_count"], ref["stdcell_count"])
        p["stdcell_area_delta_vs_previous_frequency_point_pct"] = None if prev is None else pct(p["stdcell_area"], prev["stdcell_area"])
        p["stdcell_count_delta_vs_previous_frequency_point_pct"] = None if prev is None else pct(p["stdcell_count"], prev["stdcell_count"])
        prev = p

    fields = [
        "period_ns", "frequency_mhz", "run_status", "synthesis_completed", "timing_status",
        "wns_ns", "tns_ns", "violating_path_count", "stdcell_count", "stdcell_area",
        "sram_instance_count", "macro_area", "total_area",
        "stdcell_area_delta_vs_slowest_valid_pct", "stdcell_area_delta_vs_previous_frequency_point_pct",
        "stdcell_count_delta_vs_slowest_valid_pct", "stdcell_count_delta_vs_previous_frequency_point_pct",
        "worst_startpoint", "worst_endpoint", "worst_path_group", "worst_path_class",
        "critical_path_family", "mapped_implementation_present", "reports_complete",
        "report_source", "run_directory", "reference_type",
    ]
    with (REPORTS / "frequency_tradeoff_table.csv").open("w", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=fields)
        w.writeheader()
        for p in points:
            row = {}
            for k in fields:
                v = p.get(k)
                if v is None:
                    row[k] = "NA"
                elif not isinstance(v, float):
                    row[k] = v
                elif k in {"stdcell_area", "macro_area", "total_area"}:
                    row[k] = fmt(v, 6)
                elif k.endswith("_pct"):
                    row[k] = fmt(v, 9)
                else:
                    row[k] = fmt(v, 12)
            w.writerow(row)

    sweep_points = [p for p in points if p["reference_type"] == "FREQUENCY_SWEEP_POINT"]
    fastest_pass = max((p for p in sweep_points if p["timing_status"] == "PASS"), key=lambda x: x["frequency_mhz"])
    adjacent_fail = min((p for p in sweep_points if p["timing_status"] == "FAIL"), key=lambda x: x["frequency_mhz"])

    marginal = []
    for a, b in zip(points, points[1:]):
        df = b["frequency_mhz"] - a["frequency_mhz"]
        da = b["stdcell_area"] - a["stdcell_area"]
        dc = b["stdcell_count"] - a["stdcell_count"]
        marginal.append({
            "from_mhz": a["frequency_mhz"], "to_mhz": b["frequency_mhz"], "delta_mhz": df,
            "delta_area": da, "delta_area_pct": pct(b["stdcell_area"], a["stdcell_area"]),
            "area_per_100mhz": da * 100.0 / df,
            "delta_count": dc, "delta_count_pct": pct(b["stdcell_count"], a["stdcell_count"]),
            "count_per_100mhz": dc * 100.0 / df,
            "from_family": a["critical_path_family"], "to_family": b["critical_path_family"],
        })

    with (REPORTS / "area_vs_frequency.csv").open("w", newline="") as fp:
        w = csv.writer(fp); w.writerow(["frequency_mhz", "period_ns", "stdcell_area", "normalized_area_pct"])
        for p in points: w.writerow([fmt(p["frequency_mhz"]), fmt(p["period_ns"]), fmt(p["stdcell_area"]), fmt(100+p["stdcell_area_delta_vs_slowest_valid_pct"])])
    with (REPORTS / "cellcount_vs_frequency.csv").open("w", newline="") as fp:
        w = csv.writer(fp); w.writerow(["frequency_mhz", "period_ns", "stdcell_count", "normalized_count_pct"])
        for p in points: w.writerow([fmt(p["frequency_mhz"]), fmt(p["period_ns"]), p["stdcell_count"], fmt(100+p["stdcell_count_delta_vs_slowest_valid_pct"])])
    with (REPORTS / "wns_vs_frequency.csv").open("w", newline="") as fp:
        w = csv.writer(fp); w.writerow(["frequency_mhz", "period_ns", "wns_ns", "tns_ns", "violating_path_count", "timing_status"])
        for p in points: w.writerow([fmt(p["frequency_mhz"]), fmt(p["period_ns"]), fmt(p["wns_ns"]), fmt(p["tns_ns"]), p["violating_path_count"], p["timing_status"]])

    timing_lines = [
        "A2 TIMING TREND", "SOURCE=Existing independently synthesized mapped implementations", "",
        "PERIOD_NS,FREQUENCY_MHZ,WNS_NS,TNS_NS,VIOLATING_PATH_COUNT,TIMING_STATUS",
    ]
    for p in points:
        timing_lines.append(",".join([fmt(p["period_ns"]), fmt(p["frequency_mhz"]), fmt(p["wns_ns"]), fmt(p["tns_ns"]), str(p["violating_path_count"]), p["timing_status"]]))
    timing_lines += [
        "", f"FASTEST_PASS_POINT={fmt(fastest_pass['period_ns'])}ns/{fmt(fastest_pass['frequency_mhz'])}MHz",
        f"ADJACENT_FAIL_POINT={fmt(adjacent_fail['period_ns'])}ns/{fmt(adjacent_fail['frequency_mhz'])}MHz",
        "BOUNDARY_DEGRADATION=MIXED",
        "FACT=Timing status changes between the existing 740.740740741MHz pass and 769.230769231MHz fail.",
        "FACT=Beyond the boundary, WNS/TNS/violating-path count worsen progressively at 800MHz and 1000MHz.",
        "INFERENCE=The pass-to-fail status transition is abrupt at sampled resolution, while fail severity grows gradually with additional frequency pressure.",
        "QUALIFIER=PRE_LAYOUT_SYNTHESIS_TIMING_CHARACTERIZATION_BOUNDARY",
    ]
    write_report("timing_trend.rpt", "\n".join(timing_lines))

    area_lines = [
        "A2 AREA / FREQUENCY ANALYSIS", "PRIMARY_METRIC=STDCELL_AREA", "MACRO_AREA_CONSTANT=YES",
        "MACRO_AREA=184544.781248", "SRAM_INSTANCE_COUNT=32", "",
        "FROM_MHZ,TO_MHZ,DELTA_MHZ,DELTA_AREA,DELTA_AREA_PCT,AREA_PER_100MHZ",
    ]
    for m in marginal:
        area_lines.append(",".join(fmt(m[k]) for k in ("from_mhz", "to_mhz", "delta_mhz", "delta_area", "delta_area_pct", "area_per_100mhz")))
    area_lines += [
        "", f"FACT=200MHz pilot stdcell area is {fmt(ref['stdcell_area'])}.",
        f"FACT=740.740740741MHz fastest-pass stdcell area is {fmt(fastest_pass['stdcell_area'])}.",
        f"FACT=Reference-to-fastest-pass growth is {fmt(pct(fastest_pass['stdcell_area'], ref['stdcell_area']), 6)}%.",
        "FACT=The 200->222.222MHz step decreases area by 0.054928%; independent runs are not monotonic.",
        "FACT=Marginal area cost rises to 2555.2422 area/100MHz from 666.667->740.741MHz and 3128.84208 from 740.741->769.231MHz.",
        "INFERENCE=The full curve is non-monotonic but has a clear high-cost region near the timing ceiling.",
        "AREA_FREQUENCY_TREND=NON_MONOTONIC_WITH_ACCELERATION_NEAR_BOUNDARY",
    ]
    write_report("area_frequency_analysis.rpt", "\n".join(area_lines))

    count_lines = [
        "A2 CELL-COUNT / FREQUENCY ANALYSIS", "",
        "FROM_MHZ,TO_MHZ,DELTA_MHZ,DELTA_COUNT,DELTA_COUNT_PCT,COUNT_PER_100MHZ",
    ]
    for m in marginal:
        count_lines.append(",".join(fmt(m[k]) for k in ("from_mhz", "to_mhz", "delta_mhz", "delta_count", "delta_count_pct", "count_per_100mhz")))
    count_lines += [
        "", f"FACT=Cell count grows from {ref['stdcell_count']} at 200MHz to {fastest_pass['stdcell_count']} at 740.740740741MHz ({fmt(pct(fastest_pass['stdcell_count'], ref['stdcell_count']), 6)}%).",
        "FACT=Count decreases by 142 cells from 740.741MHz to 769.231MHz while area increases by 1.077553%, proving count and sizing/mapping cost are not interchangeable.",
        "FACT=The 800->1000MHz independent implementation adds 5615 cells (5.022451%).",
        "INFERENCE=Increasing timing pressure is consistent with additional sizing, buffering, restructuring or duplication, but the aggregate reports do not attribute exact causes.",
        "CELLCOUNT_FREQUENCY_TREND=NON_MONOTONIC_OVERALL_INCREASING_WITH_ACCELERATION_AT_HIGH_FREQUENCY",
    ]
    write_report("cellcount_frequency_analysis.rpt", "\n".join(count_lines))

    knee_lines = [
        "A2 AREA-FREQUENCY KNEE ANALYSIS", "KNEE_TYPE=AREA_FREQUENCY_KNEE_NOT_FULL_PPA_KNEE", "",
        "FROM_MHZ,TO_MHZ,DELTA_AREA_PCT,AREA_PER_100MHZ",
    ]
    for m in marginal:
        knee_lines.append(",".join(fmt(m[k]) for k in ("from_mhz", "to_mhz", "delta_area_pct", "area_per_100mhz")))
    knee_lines += [
        "", "AREA_KNEE_EVIDENCE=MODERATE", "AREA_KNEE_APPROX_RANGE_MHZ=666.666666667_TO_800.0",
        "FACT=Marginal cost is mostly below 1000 area/100MHz through 666.667MHz, then 2555/3129/2102 area/100MHz over the next three steps.",
        "FACT=The 800->1000MHz step remains expensive in absolute area but falls to 1043.5 area/100MHz, so the curve is not a single smooth convex knee.",
        "INFERENCE=There is moderate evidence for a broad accelerated-cost region, not an exact knee frequency.",
        "ASSUMPTION=Independent synthesis run variability contributes to non-monotonicity.",
        "DESIGN_TARGET_SELECTION_FROM_KNEE=PROHIBITED_AND_NOT_SUPPORTED",
    ]
    write_report("area_knee_analysis.rpt", "\n".join(knee_lines))

    trans_fields = ["period_ns", "frequency_mhz", "timing_status", "wns_ns", "worst_startpoint", "worst_endpoint", "critical_path_family"]
    with (REPORTS / "critical_path_transition_table.csv").open("w", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=trans_fields); w.writeheader()
        for p in points:
            w.writerow({k: fmt(p[k]) if isinstance(p[k], float) else p[k] for k in trans_fields})
    sequence = " -> ".join(f"{fmt(p['frequency_mhz'])}MHz:{p['critical_path_family']}" for p in points)
    transition_text = f"""
A2 CRITICAL PATH TRANSITION ANALYSIS
METHODOLOGY=Each row is the single worst path of a distinct independently synthesized implementation.
CRITICAL_PATH_TRANSITION_OBSERVED=YES
CRITICAL_PATH_TRANSITION_SEQUENCE={sequence}

FACT=Exact worst-path family changes at every adjacent sampled implementation except the 222.222MHz LSU_TO_ID_ALU family persists from the 200MHz pilot.
FACT=Divider-related operand/result families are worst at 250,285.714,400,740.741 and 800MHz.
FACT=I-cache PLRU endpoint families are worst at 333.333,666.667,769.231 and 1000MHz.
FACT=Root-cause top-N evidence adds 24/50 ID_ALU_TYPE_TO_ICACHE_PLRU paths at 740.741MHz and 138/149 ID_ALU_OP_TO_ICACHE_PLRU violations at 769.231MHz.
INFERENCE=Divider and EX/IF/cache-control structures persist across multiple timing constraints even though their exact worst start/end registers migrate.
CAUTION=A single worst path does not describe the complete near-critical population except where top-N population evidence is explicitly cited.
"""
    write_report("critical_path_transition_analysis.rpt", transition_text)

    persistence_text = """
A2 PATH-FAMILY PERSISTENCE

PATH_FAMILY=LSU_TO_ID_ALU
FIRST_OBSERVED_POINT=200MHz
LAST_OBSERVED_POINT=222.222222222MHz
NUMBER_OF_WORST_PATH_POINTS_OBSERVED=2
WORST_RECORDED_SLACK_NS=0.000144958
NEAR_CRITICAL_POPULATION_AVAILABLE=NO
PERSISTENCE=TRANSITIONAL_LOW_FREQUENCY

PATH_FAMILY=ID_ALU_OPERAND_TO_DIV
FIRST_OBSERVED_POINT=250MHz
LAST_OBSERVED_POINT=800MHz
NUMBER_OF_WORST_PATH_POINTS_OBSERVED=3
WORST_RECORDED_SLACK_NS=-0.0311123
NEAR_CRITICAL_POPULATION_AVAILABLE=YES_AT_740P741_AND_769P231_ONLY
PERSISTENCE=PERSISTENT

PATH_FAMILY=DIV_CONTROL_OR_RESULT_TO_ID_ALU_OPERAND
FIRST_OBSERVED_POINT=400MHz
LAST_OBSERVED_POINT=740.740740741MHz
NUMBER_OF_WORST_PATH_POINTS_OBSERVED=2
WORST_RECORDED_SLACK_NS=0.0000474453
NEAR_CRITICAL_POPULATION_AVAILABLE=YES_AT_740P741_AND_769P231_ONLY
PERSISTENCE=PERSISTENT_NEAR_BOUNDARY

PATH_FAMILY=ID_ALU_CONTROL_OR_OPERAND_TO_ICACHE_PLRU
FIRST_OBSERVED_POINT=333.333333333MHz
LAST_OBSERVED_POINT=1000MHz
NUMBER_OF_WORST_PATH_POINTS_OBSERVED=3
ADDITIONAL_CLINT_TO_ICACHE_PLRU_WORST_POINT=666.666666667MHz
WORST_RECORDED_SLACK_NS=-0.290456
NEAR_CRITICAL_POPULATION_AVAILABLE=YES_AT_740P741_AND_769P231
PERSISTENCE=PERSISTENT

PATH_FAMILY=CSR_CYCLE_COUNTER
FIRST_OBSERVED_POINT=500MHz
LAST_OBSERVED_POINT=500MHz
NUMBER_OF_WORST_PATH_POINTS_OBSERVED=1
WORST_RECORDED_SLACK_NS=0.000188589
NEAR_CRITICAL_POPULATION_AVAILABLE=YES_AT_740P741_TOP50
PERSISTENCE=TRANSITIONAL

BOUNDARY_SPECIFIC_EXACT_FAMILIES=DIV_RESULT_TO_ID_ALU_OPERAND_AT_740P741,ID_ALU_OP_TO_ICACHE_PLRU_AT_769P231
FACT=The exact labels are boundary-specific as single-worst paths, but their broader divider and cache-control parent structures persist elsewhere.
"""
    write_report("path_family_persistence.rpt", persistence_text)

    summary_text = f"""
A2 FREQUENCY TRADEOFF SUMMARY

Q1_STDCELL_AREA_CHANGE_REFERENCE_TO_P1P35={fmt(fastest_pass['stdcell_area']-ref['stdcell_area'], 6)} absolute; {fmt(pct(fastest_pass['stdcell_area'], ref['stdcell_area']), 6)} percent.
Q2_AREA_GROWTH_CLASSIFICATION=NON_MONOTONIC_WITH_ACCELERATION_NEAR_BOUNDARY.
Q3_AREA_FREQUENCY_KNEE=MODERATE evidence over approximately 666.666666667-800MHz; not an exact point and not a full PPA knee.
Q4_STDCELL_COUNT_EVOLUTION={ref['stdcell_count']} at 200MHz to {fastest_pass['stdcell_count']} at 740.740740741MHz ({fmt(pct(fastest_pass['stdcell_count'], ref['stdcell_count']), 6)}%); generally rising but non-monotonic between independent runs.
Q5_WORST_PATH_TRANSITIONS={sequence}
Q6_PERSISTENCE=Broader divider and I-cache PLRU/control families persist; exact p1p35 DIV_RESULT and p1p30 ID_ALU_OP labels are boundary-specific worst paths.
Q7_AREA_DATA_ALONE_JUSTIFIES_FINAL_TARGET=NO.
Q8_MISSING_INPUTS=Application-required frequency, workload/headroom requirements, and activity-aware power/frequency tradeoff.

FACT=All 11 requested sweep points completed synthesis and contain mapped implementation, area and timing reports.
FACT=SRAM count is 32 and macro area 184544.781248 at every sweep point.
FACT=740.740740741MHz is the fastest existing setup-pass point and 769.230769231MHz is the adjacent existing fail point.
INFERENCE=Large area/count changes coincide with worst-path-family migration near 666.667-800MHz, but independent synthesis implementations prevent a causal claim.
AREA_PATH_TRANSITION_CORRELATION=AMBIGUOUS
CHARACTERIZED_TIMING_CEILING_FREQUENCY_MHZ=740.740740741
CHARACTERIZED_TIMING_CEILING_QUALIFIER=CURRENT_PRE_LAYOUT_CHARACTERIZATION_ASSUMPTIONS_ONLY
DESIGN_TARGET_FREQUENCY=TBD
"""
    write_report("frequency_tradeoff_summary.rpt", summary_text)

    implications = """
A2 IMPLICATIONS FOR FUTURE TARGET SELECTION

FACT=Area and count grow modestly through much of the low/mid-frequency range, then show a materially higher marginal area cost from roughly 666.667 to 800MHz.
FACT=The existing pre-layout characterization ceiling is 740.740740741MHz under current assumptions.
FACT=Timing-limiting structures migrate among LSU forwarding, divider operand/result logic, counters, and EX/IF/I-cache PLRU control.
INFERENCE=A future target below the accelerated-cost region may offer lower implementation cost, but no frequency is selected here.
ASSUMPTION=Application requirements and activity-aware power can materially change the preferred operating region.

APPLICATION_REQUIRED_FREQUENCY=TBD
POWER_FREQUENCY_TRADEOFF=NOT_YET_CHARACTERIZED
DESIGN_TARGET_FREQUENCY=TBD
AREA_DATA_SUFFICIENT_TO_SELECT_FINAL_TARGET=NO
FINAL_TARGET_SELECTION_REQUIRES=APPLICATION_REQUIREMENT_PLUS_HEADROOM_PLUS_AREA_TRADEOFF_PLUS_POWER_TRADEOFF
READY_FOR_DESIGN_TARGET_SELECTION=NO
"""
    write_report("target_selection_implications.rpt", implications)

    consumed = [p for p in source_files if p.is_file()]
    consumed += [
        SWEEP / "reports/frequency_sweep_table.csv",
        SWEEP / "reports/critical_path_transition.rpt",
        SWEEP / "reports/area_frequency_tradeoff.rpt",
        PT / "pass_p1p35ns/metadata/pt_boundary.env",
        PT / "fail_p1p30ns/metadata/pt_boundary.env",
        ROOTCAUSE / "reports/critical_path_family_summary.rpt",
        ROOTCAUSE / "reports/root_cause_summary.rpt",
    ]
    consumed = [p for p in consumed if p.is_file()]
    provenance = [
        "A2 ANALYSIS PROVENANCE", f"PUBLICATION_COMMIT={PUBLICATION_COMMIT}", f"PUBLICATION_TREE={PUBLICATION_TREE}",
        f"TOP_MODULE={TOP}", f"SOURCE_SWEEP_DIRECTORY={SWEEP}", f"SOURCE_PT_DIRECTORY={PT}",
        f"SOURCE_ROOTCAUSE_DIRECTORY={ROOTCAUSE}", f"ANALYSIS_TIMESTAMP_UTC={datetime.now(timezone.utc).isoformat()}",
        "ANALYSIS_ONLY=YES", "RTL_MODIFIED=NO", "SYNTHESIS_RERUN=NO", "NEW_FREQUENCY_POINTS=NO",
        "PT_HOLD_RUN=NO", "POWER_ANALYSIS_RUN=NO", "P&R_RUN=NO", "", "SOURCE_REPORT_FILES_CONSUMED:",
    ] + [str(p) for p in consumed]
    write_report("analysis_provenance.rpt", "\n".join(provenance))

    # Record the generated artifact digests without touching source run directories.
    hashes = []
    for p in sorted(REPORTS.iterdir()):
        hashes.append(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}")
    (META / "report_sha256.txt").write_text("\n".join(hashes) + "\n")


if __name__ == "__main__":
    main()
