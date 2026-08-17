# A2 Phase 2 Existing-Interface Collector

## Scope

Phase 2 adds an opt-in C++ collector only. It reads public `Vtop` ports already
declared by `rv64im_core_sim_top`: `wb_sign`, `wb_pc`, `wb_inst`, `wb_intr`,
`wb_device`, `brn_num`, and `bflush_num`. Cycle progression is observed in the
existing `single_cycle()` loop. It does not use generated private hierarchy,
modify SystemVerilog, or change DiffTest ordering.

Enable collection by setting `PERF_RAW_OUT` to a JSON path under ignored
`out/perf/raw/`. Set `PERF_WORKLOAD` and `PERF_GIT_COMMIT` to identify the
invocation, for example:

```sh
mkdir -p out/perf/raw
PERF_RAW_OUT=out/perf/raw/dummy.json \
PERF_WORKLOAD=dummy PERF_GIT_COMMIT="$(git rev-parse HEAD)" \
make run TEST=dummy
```

Without `PERF_RAW_OUT`, the collector is inert and produces no output.

## Raw schema

Schema version `a2-raw-v1` contains:

- `git_commit`, `a2_base_commit`, `workload`, `measurement_scope`, and
  `roi_valid` metadata.
- `simulator_cycle_count`, counted once per existing simulated clock cycle.
- `wb_observation_count` and per-observation `cycle`, `wb_pc`, `wb_inst`,
  `wb_intr`, and `wb_device` values, sampled only when existing `wb_sign` is
  asserted.
- Aggregate `wb_intr_count`, `wb_device_count`, final `brn_num`, final
  `bflush_num`, and simulator exit status.

`measurement_scope` is always `full_run` and `roi_valid` is always `false`.
These data include reset, startup, initialization, device activity, traps, and
termination where they occur. They are not kernel-only performance results.

## Raw versus validated

`wb_observation_count` is deliberately not named `retired_instruction_count`
or `instret`. Phase 1 classified `wb_sign` as `PARTIAL_RETIREMENT_EVENT`:
the C++ harness uses it as a DiffTest boundary, but source review has not
proved one-to-one architectural retirement through bubbles, flushes, stores,
CSR/system activity, and interrupts. Consequently the collector does not
publish IPC, CPI, retired load/store counts, or branch retirement counts.

`brn_num` is the existing simulation-top counter driven by ALU `bjp_req`.
`bflush_num` is driven by ALU `o_alu_flush`. They are reported as coarse raw
final values, not as validated branch and branch-mispredict metrics. In
particular, `bflush_num` is not a branch-mispredict count.

## Deferred observability

The existing interface does not expose cache miss transactions, I-cache wait,
D-cache/memory wait, branch-mispredict events, dependency/load-use stalls,
divider wait, or cause-qualified pipeline flushes. Those remain unavailable
until a separately approved Phase 3 simulation-only instrumentation step.
ROI mechanism and retirement validation also remain unresolved from Phase 1.

## Consistency checks

The collector derives `wb_observation_count` from exactly one stored record per
sampled `wb_sign`; aggregate interrupt/device counts are derived from those same
records. Repeated identical runs should produce byte-identical JSON when the
same metadata is supplied. The collector is observational: sampling happens
after the existing `exec_once()` work and does not affect its DiffTest, device,
or trap behavior.
