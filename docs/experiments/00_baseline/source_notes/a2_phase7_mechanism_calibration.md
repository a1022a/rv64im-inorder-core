# A2 Phase 7 Mechanism Calibration

## Scope and Phase 6 Baseline

[MEASURED] Phase 6 established exclusive ROI accounting with fixed precedence and retained all raw overlapping counters. This phase adds only two simulation-only episode counters using existing raw ports; it changes no RTL, ROI, raw counter, or exclusive-attribution semantics. `wb_sign` remains a `PARTIAL_RETIREMENT_EVENT`, so this is an ROI execution-cycle model and does not report architectural retirement, IPC, CPI, retired loads/stores, or MPKI.

## Dependency Event Semantics

[RTL] `perf_load_use_stall` is `core.idu_pipe_stall`, from `o_rf_id_flush_ex`, which is asserted when either IDU source register matches an EXU load destination with write enable. The Phase 7 counter increments only on a sampled low-to-high transition of `perf_load_use_stall` while the ROI is active. It counts a contiguous sampled high run as one dependency/load-use episode; occupancy remains the existing raw/exclusive cycle count.

[MEASURED] The existing directed ROI has one intentional load-use sequence. It reports 11 raw load-use stall samples, one dependency episode, and one exclusive dependency cycle because ten raw samples are superseded by higher-priority D-cache wait under Phase 6 precedence. This validates the distinction between a raw sampled high run and an exclusive attribution count.

| Workload | Dependency episodes | Exclusive dependency cycles | Effective accounting penalty | Predicted cycles | Residual |
|---|---:|---:|---:|---:|---:|
| CPU bubble-sort calibration point | 190 | 190 | 1.00 exclusive cycles/episode | 190 | 0 |
| FIB cross-workload validation | 224 | 224 | 1.00 using calibration coefficient | 224 | 0 (0.00%) |

[CALIBRATED MODEL] For these two ROIs, `exclusive_dependency_cycles = dependency_load_use_episodes × 1.00` under the sampled transition and exclusive precedence definitions. The bubble-sort coefficient is a calibration point; FIB is a cross-workload validation point. This is not an architectural per-hazard latency claim: every observed representative episode is one sampled cycle long after precedence, and different memory overlap patterns can change the relationship.

**Dependency classification: `CALIBRATED_AND_VALIDATED`.**

## Branch Recovery Event Semantics

[RTL] `perf_flush_branch` is `exu_pipe_alu_flush && !mem_pipe_stall`. Active `o_alu_flush` includes conditional direction correction (`cond_err`) and, with the active RAS configuration, `jalr && jalr_err`; it does not imply that every conditional error is an architectural recovery event, and it can include redirect causes beyond conditional direction correction. The Phase 7 branch counter increments only on a sampled low-to-high transition of `perf_flush_branch` while the ROI is active. It is named a recovery episode, not a branch-misprediction count.

[MEASURED] The directed control-flow ROI contains known taken/not-taken control flow, a direction-error path, JAL, JALR, and labelled wrong-path code. It reports two branch-flush samples and two recovery episodes; the runner rejects observation of all three wrong-path labels. This validates the transition counter as an episode denominator for the exposed recovery signal, not as an architectural branch taxonomy.

| Workload | Recovery episodes | Exclusive branch-recovery cycles | Effective accounting penalty | Predicted cycles | Residual |
|---|---:|---:|---:|---:|---:|
| FIB calibration point | 603 | 603 | 1.00 exclusive cycles/episode | 603 | 0 |
| CPU bubble-sort cross-workload validation | 105 | 105 | 1.00 using calibration coefficient | 105 | 0 (0.00%) |

[CALIBRATED MODEL] For these two ROIs, `exclusive_branch_recovery_cycles = branch_recovery_episodes × 1.00` under the sampled flush-transition and precedence definitions. The equality demonstrates one sampled exclusive cycle per exposed recovery episode in these workloads. It does not establish a general redirect latency or identify conditional direction corrections separately from JALR target-error recovery.

**Branch classification: `CALIBRATED_AND_VALIDATED`** for the exposed sampled recovery-episode convention; architectural branch-misprediction penalty remains out of scope.

## One Representative D-cache Attempt

[MEASURED] The one allowed additional workload was existing `bench_dinic_run`, a representative maximum-flow kernel whose ROI begins at `bench_dinic_run` entry `0x800025ec` and ends at the established MicroBench caller-side post-return boundary `0x80004a94`. It excludes setup, validation, reporting, device/timing work, and termination. Two runs were deterministic, valid, and clean.

| Workload | Accepted D-cache observations | Raw D wait | Exclusive D-cache/memory cycles |
|---|---:|---:|---:|
| CPU bubble-sort | 3 | 26 | 26 |
| MicroBench Dinic | 1 | 19 | 19 |

[MEASURED] Dinic is representative but supplies less D-cache activity than bubble-sort. It therefore does not make an accepted-miss-cost coefficient identifiable or provide meaningfully stronger representative evidence.

**D-cache classification: `INSUFFICIENT_EVIDENCE`.** No D-cache coefficient is fitted.

## Determinism and Functional Validation

[MEASURED] FIB, bubble-sort, and Dinic affected ROI runs were valid, had exclusive sum equal ROI cycles, reached `HIT GOOD TRAP`, and had no ASan, DiffTest, abort, assertion, or non-convergence failure. FIB and bubble-sort run pairs had equal canonical JSON measurement content. `make doctor`, `make -j1 build`, directed ROI validation, `make run TEST=dummy`, `make smoke`, and full regression passed.

Full regression: CPU 33/33, KLIB 33/33, KLIB unit 8/8, MicroBench, AM hello/RTC, timer128 interrupt/mret, and directed machine interrupts all passed; DiffTest fatal, bad trap, abort, assertion, and non-convergence markers were zero.

## Completion Decision and Recommendation

| Mechanism | Classification | Confidence limit |
|---|---|---|
| Dependency/load-use | `CALIBRATED_AND_VALIDATED` | Sampled episode accounting only; not universal hazard latency. |
| Branch recovery | `CALIBRATED_AND_VALIDATED` | Exposed flush episodes only; not architectural misprediction taxonomy. |
| D-cache | `INSUFFICIENT_EVIDENCE` | Two representative points are weak and do not identify miss cost. |

[RATIONALE] The recommended first future DSE target is dependency/load-use behavior: bubble-sort shows the largest representative exclusive share (10.22%), its episode-accounting relationship is validated on FIB, and it has clearer representative evidence than D-cache. This is a recommendation only; it does not authorize DSE, RTL P1 work, predictor changes, or cache sweeps. Branch predictor remains the next evidence-supported candidate (FIB branch recovery 5.03%), but redirect subtype ambiguity and predictor implementation scope should be resolved before a branch DSE.

## Limitations

- Exclusive categories remain deterministic accounting, not physical ground truth.
- The fitted 1.00 relationships are sampled accounting coefficients with zero same-definition residual, not cross-microarchitecture predictive latency models.
- JALR target error remains provisional and is neither counted nor ranked separately.
- No D-cache coefficient, total-cycle equation, or DSE is produced in this phase.
