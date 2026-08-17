# A2 Performance Metric Contract

This document records the Phase 4 evidence-backed contract. The collector is
simulation-only C++; it does not alter functional or synthesis RTL.

## Measurement rules

- The clock is the DUT rising edge (`posedge clk`). A cycle metric counts one
  sampled rising-edge interval while the ROI is active; a pulse event counts
  once when its source is true on that edge.
- Event counts and cycle counts are separate. A level held for four cycles is
  one transaction event only if the contract names its accepted-edge pulse;
  it is four wait cycles if the contract names occupancy.
- The opt-in ROI uses `PERF_ROI_START_PC` and `PERF_ROI_END_PC`, matched to
  `wb_sign`/`wb_pc`. The start-marker writeback resets all counters and is
  excluded. Sampling begins with following edges. The end-marker writeback is
  excluded and disables collection before subsequent edges. `roi_valid` is
  true only when both markers appear in order. Without both variables, the
  default remains Phase 3 `full_run` collection.
- Raw simultaneous indicators must be retained conceptually; future headline
  CPI attribution must assign each physical cycle once. No priority is claimed
  where the RTL does not prove one.
- Wrong-path activity is not architectural activity. Fetch/cache events are
  explicitly speculative-capable; committed instruction events require the
  retirement conclusion below.

## Retirement contract

`rv64im_core_sim_top.sv:21-24` counts `bjp_req` and `o_alu_flush` into coarse
totals. The candidate writeback event is generated at
`rv64im_core_sim_top.sv:28-63`: `mem_pc`/`wbu_pc` and instruction registers
advance whenever `pipe_wbu_stall` is low; `wb_sign` is `wb_start` or a latched
`wb_buff` combined with nonzero `wbu_pc` and `!wb_wait`.

`sim/csrc/sim_main.cpp:217-240` performs one `difftest_step()` for each
`wb_sign` event after the first event, injects an interrupt when `wb_intr` is
set, checks registers, and calls `difftest_skip_ref()` for `wb_device`.
`sim/csrc/difftest.cpp:63-70` advances the reference by exactly one
architectural instruction per call.

Conclusion: **PARTIAL_RETIREMENT_EVENT**.

Evidence proves that the harness intentionally uses each `wb_sign` event as
the DiffTest stepping boundary, but source review does not prove that every
event is exactly one architectural retirement. In particular, `wb_buff` is
latched and never cleared, `wbu_pc` is advanced from the EXU-side register
stream rather than an explicit valid/commit interface, and flush/bubble cases
are not represented by a dedicated retirement-valid signal. Stores are tagged
through `wb_device` only for device accesses; ordinary stores have no separate
commit pulse. Branches, CSR instructions, and ordinary ALU instructions are
present only through `wb_inst` decoding. `wb_intr` represents interrupt
handling around the DiffTest step, not an independently retired instruction.

Required validation before treating `wb_sign` as retirement: directed
architectural instruction counts with bubbles, taken redirects, flushed
wrong-path instructions, ordinary stores, CSR/system instructions, ecall,
ebreak, mret, asynchronous interrupts, and device accesses must reconcile
one-for-one with DiffTest steps and architectural state checks. Until then,
`retired_instruction_count`, IPC, CPI, and committed load/store/branch counts
are `TBD` or partial observations.

Phase 4 now validates an exact `wb_sign` sequence for ordinary ALU, store,
load, load-use, divide, conditional branch/wrong-path flush, and CSR-read
instructions within a PC-marker ROI. This is a validated writeback/DiffTest
subset only; ecall, ebreak, mret, interrupt, exception, device, termination,
and arbitrary-workload retirement remain unproven, so the overall conclusion
stays `PARTIAL_RETIREMENT_EVENT`.

## Mandatory metrics

The following definitions apply inside ROI only.

| Metric | Definition | Candidate source | Status |
|---|---|---|---|
| `cycle_count` | Rising-edge intervals in ROI; count once per edge | simulator clock loop / `single_cycle()` | VALIDATED for PC-marker ROI |
| `retired_instruction_count` | One architectural instruction retirement | `wb_sign`, `wb_pc`, `wb_inst`; retirement contract above | TBD/PARTIAL |
| `IPC` | `retired_instruction_count / cycle_count` | derived | TBD until retirement/ROI proven |
| `CPI` | `cycle_count / retired_instruction_count` | derived | TBD until retirement/ROI proven |
| `branch_count` | `bjp_req` sampled while active; includes the directed conditional branches, JAL, and JALR | exposed `perf_branch_resolved_event` | VALIDATED for this event boundary |
| `branch_direction_error_count` | sampled `cond_err` level at resolution | exposed `perf_branch_direction_error` | VALIDATED for directed direction-error case |
| `jalr_target_error_count` | sampled `jalr_err` level, not an event count | exposed `perf_jalr_target_error` | PROVISIONAL; held high for 41 samples in one JALR case |
| `icache_miss_count` | one accepted lookup `req_miss`, including speculative fetches | exposed `perf_icache_miss_event` | VALIDATED deterministic raw observation; not architectural |
| `dcache_miss_count` | one accepted lookup `req_miss` | exposed `perf_dcache_miss_event` | VALIDATED deterministic raw observation |
| `icache_wait_cycles` | sampled I-cache refill/bus/stall occupancy | exposed `perf_icache_wait` | VALIDATED cycle metric; speculative-capable |
| `dcache_memory_wait_cycles` | sampled `mem_pipe_stall` occupancy | exposed `perf_dcache_memory_wait` | VALIDATED cycle metric |
| `load_count` | Retired load instructions, not speculative requests | `wb_inst` decode after retirement is proven; LSU request signals are speculative-capable | TBD |
| `store_count` | Retired stores, including ordinary memory stores; device stores separately tagged by `wb_device` | `wb_inst`/LSU state; `wb_device` is only device tag | TBD |
| `dependency_stall_cycles` | sampled `idu_pipe_stall` while memory is not stalling; not a flush | exposed `perf_flush_dependency` (legacy port name) | VALIDATED load-use presence; rename corrects schema semantics |
| `divider_wait_cycles` | sampled `div_op & !div_ack` occupancy | exposed `perf_divider_wait` | VALIDATED against directed pipeline-block interval |
| `flush_count` | sampled `pipec_flush` level | exposed `perf_flush_event` | VALIDATED raw level; not a generic mispredict count |

For all event metrics, repeated levels must be edge-qualified by the
transaction acceptance or resolution event named above. For all cycle metrics,
the level is sampled once per rising edge. Cache miss events must not be
derived by summing `state_is_wbus`/`state_is_rbus` or a held miss state.

## ROI candidates

| Candidate | Source changes | Applicability | Assessment |
|---|---|---|---|
| PC/symbol interval | none for fixed linked assembly; symbol metadata needed | assembly microbenchmarks; possibly MicroBench ELF symbols | plausible, but current harness has no ROI API |
| Explicit software marker | benchmark source plus simulator recognition | excellent for assembly; requires source convention for MicroBench | functional behavior may be unchanged if marker is a reserved instruction, but not established |
| Simulator-side PC/ebreak detection | C++ change | assembly and existing trap convention | can exclude termination, but Phase 1 must not implement it |
| Existing `wb_device`/`ebreak` hooks | none initially | device and termination boundaries | useful exclusions, not a complete start marker |

The PC-marker mechanism is used only for fixed linked directed assembly.
External workload ROI integration remains **TBD**.

## Overlap policy

`rv64im_core_pipe_ctrl.sv:21-27` forms a combined stall vector from EXU,
memory, and IDU causes, while flush generation is separately masked by memory
stall. Therefore I-cache wait, D-cache wait, dependency stall, divider wait,
generic stall, branch recovery, and interrupt/exception handling can overlap or
mask one another. Phase 4 records raw indicators separately and defers a
mutually-exclusive priority to the calibrated model after observability is
available. Residual/unclassified cycles are required rather than double
counting overlapping causes.
