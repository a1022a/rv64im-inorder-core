# A2 Phase 6 ROI Cycle Model Design

## Objective and scope

Phase 6 designs, but does not yet implement, an analytical A2 ROI execution
cycle model. Its primary quantity is measured ROI execution cycles. It is not
an architectural CPI model: `wb_sign` remains a `PARTIAL_RETIREMENT_EVENT`, so
writeback observations are not architectural retired instructions. This design
does not report retired instructions, IPC, CPI, retired load/store counts, or
MPKI.

[MEASURED] The deterministic Phase 5 reference is
`docs/modeling/a2_phase5_workload_baseline.md`: FIB (11,978 cycles), CPU
bubble-sort (1,860 cycles), and CPU div (1,883 cycles). CPU div is a directed
divider stress point, not representative application evidence.

## Raw-observation contract

[RTL] The simulation-only raw ports are sampled after the rising-edge
evaluation in `sim/csrc/sim_main.cpp`. Accepted cache-miss fields are request
events; wait, stall, and flush fields are sampled levels. The Phase 5 JSON
stores only aggregates, not the simultaneous raw-port vector for each cycle.
Consequently aggregate occupancies must not be added and do not themselves
reconstruct exclusive cycle causes.

[RTL] `jalr_target_error` is an ALU internal held/provisional signal. It is
excluded from this design's attribution and model equations.

## Source and control trace

| Raw condition | Exact observed source | Stage/control scope | Progress effect and masking |
|---|---|---|---|
| I-cache wait | `icache.state_is_wbus || state_is_rbus || stall_c1` | IFU request/response path; cache instance connects to IFU in `rv64im_core_top.sv` | Cache transaction/backpressure occupancy. This port alone does not prove a global pipe-control stall. IFU invalidates fetched data under `i_if_stall`/flush. |
| D-cache/memory wait | `core.mem_pipe_stall` | LSU/MEM; input to pipe control | `o_pipec_stall` freezes IF, ID, EX, MEM, and WB. It masks EXU and IDU flush outputs in pipe control. |
| Dependency/load-use | `core.idu_pipe_stall`, from `regfile.o_rf_id_flush_ex` | IDU hazard between decoded source and EXU load destination | Pipe control stalls IF and ID only and flushes EX only when memory is not stalled. A concurrent MEM stall freezes all stages and masks its flush output. |
| Divider wait | `alu.div_op && !alu.div_ack` | EXU | Included in `alu.o_alu_stall`; pipe control freezes all five stages. The divider receives the pipe stall and is reset by ALU flush. |
| Branch recovery candidate | `core.exu_pipe_alu_flush && !core.mem_pipe_stall` | EXU redirect/control recovery | Pipe control flushes IF, ID, and EX. The exposed branch-flush port is already suppressed during a MEM stall. It includes active ALU redirect causes, so it is a recovery candidate rather than an architectural branch-misprediction count. |
| Generic flush | `|core.pipec_flush` | Pipe control output | OR of interrupt, EXU, and dependency flush vectors; it can overlap each cause and is not a headline penalty category. |

[RTL] The governing equations in `rtl/vsrc/core/rv64im_core_pipe_ctrl.sv` are:

```
stall = all_stages(exu_stall || mem_stall) || if_id(idu_stall)
flush = interrupt_flush(masked at MEM)
      || exu_flush(!mem_stall, IF/ID/EX)
      || idu_stall(!mem_stall, EX)
```

`alu.o_alu_stall = (div_op && !div_ack) || i_alu_addr_stall`; the load-use
hazard is `EXU load destination matches either IDU source`; and the branch
direction error is `cond_err = bx_if_cond && (jump_res ^ prediction)`.

## Overlap and masking matrix

The entries mean: **yes** is simultaneously possible or not excluded by the
observed equations; **masked** means pipe control explicitly suppresses an
observable flush; **TBD** means source review does not prove an invariant.
This is not a measured co-occurrence matrix.

|  | I wait | D wait | dependency | divider | branch recovery |
|---|---|---|---|---|---|
| I wait | — | yes | yes | yes | yes |
| D wait | yes | — | yes; dependency flush masked | yes; both request global stall | branch-flush port masked |
| dependency | yes | yes; flush masked | — | yes not excluded by aggregate ports | yes not excluded at raw-source level |
| divider | yes | yes; D wait controls global freeze | yes not excluded by aggregate ports | — | TBD; ALU instruction classes suggest exclusion, but no formal one-hot proof is used |
| branch recovery | yes | exposed branch port no (masked) | yes not excluded at raw-source level | TBD | — |

[RTL] The matrix is conservative because the ports are from different pipeline
locations and the current aggregate JSON loses each cycle's joint state.

## Proposed exclusive attribution

[MODEL] A future simulation-only classifier should assign exactly one label at
each sampled ROI edge using the already exposed raw port values:

1. `dcache_memory_wait`: `perf_dcache_memory_wait`
2. `divider_block`: `perf_divider_wait` and not D-cache/memory wait
3. `branch_recovery`: `perf_flush_branch` and neither higher category
4. `dependency_load_use`: `perf_load_use_stall` and neither higher category
5. `icache_wait`: `perf_icache_wait` and none of the above
6. `other_unclassified`: every remaining ROI cycle

[RATIONALE] D-cache/memory wait is first because it globally freezes all
stages and explicitly masks EXU/IDU flushes. Divider block is next because it
also drives the global EXU-stall path. Branch recovery precedes dependency
because its flush removes younger work, while dependency is an IF/ID-only
hazard. I-cache wait is last among named causes because its raw state does not
by itself prove global pipe-control ownership. `other_unclassified` preserves
the invariant rather than pretending every productive, fill/drain, interrupt,
or unobservable control cycle has a verified cause.

[MODEL] The classifier invariant is:

```
dcache + divider + branch + dependency + icache + other = ROI cycles
```

This is a deterministic attribution convention informed by control precedence,
not proof that each label is the sole physical cause. It must retain the raw
overlapping aggregates alongside exclusive counts.

## Observability decision

**Outcome B.** [RTL] Existing Phase 3 simulation ports provide every raw
boolean needed for the proposed classifier; no additional RTL output or
synthesizable change is required. [TBD] Current Phase 5 JSON has only sums, so
exclusive counts cannot be reconstructed after the fact. The minimum next
change is a small opt-in simulation-only C++ classifier at the current
post-rising-edge sampling point. It should increment one of the six categories
above and emit their counts plus a sum-equals-ROI assertion. It must not change
raw metric semantics, RTL, or the measurement-window protocol.

## First-order analytical mechanism forms

These are [MODEL] forms to calibrate after exclusive attribution is recorded;
they are not measured truth and no coefficient is fitted in this iteration.

| Mechanism | Proposed form | Qualification |
|---|---|---|
| Branch recovery | `branch_recovery_cycles ≈ branch_recovery_events × effective_recovery_penalty` | Calibrate against the exclusive branch category, not raw `cond_err` alone. The IF/ID/EX flush depth suggests a near-fixed component, but cache/memory masking and different redirect types require measurement. |
| I-cache | `icache_cycles ≈ accepted_icache_misses × effective_miss_cost + response/backpressure residual` | `req_miss` is an accepted request; wait includes writeback/refill/response states. A single fixed cost is TBD until per-cycle attribution distinguishes overlap. |
| D-cache/memory | `dcache_cycles ≈ accepted_dcache_misses × effective_miss_cost + memory-wait residual` | Use accepted miss observations and exclusive memory-wait cycles. Current representative evidence is weak: only bubble-sort has three observed misses. |
| Load-use | `dependency_cycles ≈ load_use_hazard_cycles × effective_dependency_cost` | RTL shows an EXU-load-to-IDU-source hazard. It may be hidden under global memory/divider stalls; exclusive attribution avoids charging those cycles twice. Fixed one-cycle cost is TBD. |
| Divider | `divider_cycles ≈ divide_operations × effective_divider_latency` | `div_op && !div_ack` directly drives global EXU stall. CPU div provides a directed calibration point; operand/data dependence and overlap policy still require calibration. |

## Representative calibration order

1. Dependency/load-use using representative CPU bubble-sort, where exclusive
   dependency attribution is expected to be strongest (Phase 5 raw occupancy
   10.75%) and D-cache behavior is secondary.
2. Branch recovery using representative FIB, which has the strongest measured
   branch direction-error ratio (45.89%) and branch-flush evidence.
3. Divider latency using CPU div only as a directed model-validation point
   (79.24% raw divider-wait occupancy), not application weighting.
4. I-cache, present but low occupancy across all three points.
5. D-cache/memory after adding or finding a representative point with stronger
   measured behavior; the current evidence is insufficient for coefficient
   confidence.

## Limitations and exact next step

- No existing aggregate can prove a physical-cycle overlap or exclusive cause.
- Branch-flush is a control-recovery candidate, not a validated architectural
  misprediction event; generic flush includes other causes.
- I-cache wait is cache-state occupancy, not an independently proven global
  stall signal.
- `wb_observation_count` remains non-retirement observation data.
- Coefficients, a total-cycle equation, and DSE are intentionally deferred.

The exact next step is to add the described minimal simulation-only exclusive
classifier, run the existing three fixed ROIs twice, check category-sum equals
ROI cycles and determinism, then calibrate the mechanism forms. No RTL signal,
RTL architecture, cache configuration, or functional behavior change is
required for that step.
