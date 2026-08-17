# A2 Phase 6 ROI Cycle Attribution Calibration

## Scope

[MEASURED] This opt-in simulation-only model attributes ROI execution cycles. It is not an architectural CPI model: `wb_sign` remains a `PARTIAL_RETIREMENT_EVENT`. No retired-instruction count, IPC, CPI, retired load/store count, or MPKI is reported. The fixed Phase 5 ROIs are unchanged.

## Classifier and Invariant

[RTL] `perf_observer_cycle()` increments ROI cycles after each falling-edge evaluation. `perf_observer_sample_raw()` classifies the corresponding post-rising-edge raw sample. Both use the same `collecting()` predicate. ROI start resets counts and activates the following cycle; ROI end disables following cycles. No boundary compensation is used.

[MODEL] Each collected sample receives exactly one label in fixed precedence: D-cache/memory wait, divider block, branch recovery, dependency/load-use, I-cache wait, then other/unclassified. The JSON adds six `exclusive_*_cycles` fields, `exclusive_cycle_sum`, and `exclusive_cycle_sum_matches_roi`. A completed valid ROI with a failed sum returns simulator exit status one. Raw overlapping fields remain unchanged. This is deterministic accounting, not physical ground truth; `jalr_target_error_count` remains excluded.

## Validation and Reproducibility

[MEASURED] The directed ROI passed `roi_valid=true` with the machine-checkable invariant `10 + 2 + 2 + 1 + 26 + 26 = 67`. `make doctor`, `make -j1 build`, `make run TEST=dummy`, and `make smoke` passed.

[MEASURED] FIB, CPU bubble-sort, and CPU div each ran twice at their frozen ROIs. Every run had `roi_valid=true`, positive cycles, JSON exit status zero, an exclusive sum matching ROI cycles, `HIT GOOD TRAP`, and no ASan, DiffTest, abort, assertion, or non-convergence failure. Each pair's complete JSON, including observation arrays and exclusive fields, was identical.

## Raw Overlapping Observations

| Workload | ROI cycles | Raw D wait | Raw divider wait | Raw branch flush | Raw load-use | Raw I wait | Accepted I misses | Accepted D misses |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| FIB representative branch-heavy kernel | 11,978 | 0 | 0 | 603 | 224 | 159 | 19 | 0 |
| CPU bubble-sort dependency-oriented kernel | 1,860 | 26 | 0 | 105 | 200 | 16 | 2 | 3 |
| CPU div directed divider stress point | 1,883 | 0 | 1,492 | 11 | 0 | 8 | 1 | 0 |

## Exclusive Attribution

| Workload | D-cache/memory | Divider | Branch recovery | Dependency/load-use | I-cache | Other/unclassified | Sum |
|---|---:|---:|---:|---:|---:|---:|---:|
| FIB | 0 | 0 | 603 | 224 | 157 | 10,994 | 11,978 |
| CPU bubble-sort | 26 | 0 | 105 | 190 | 15 | 1,524 | 1,860 |
| CPU div | 0 | 1,492 | 11 | 0 | 8 | 372 | 1,883 |

| Workload | D-cache/memory | Divider | Branch recovery | Dependency/load-use | I-cache | Other/unclassified |
|---|---:|---:|---:|---:|---:|---:|
| FIB | 0.00% | 0.00% | 5.03% | 1.87% | 1.31% | 91.78% |
| CPU bubble-sort | 1.40% | 0.00% | 5.65% | 10.22% | 0.81% | 81.94% |
| CPU div | 0.00% | 79.24% | 0.58% | 0.00% | 0.42% | 19.76% |

Percentages are exclusive and sum to 100% subject to rounding.

## Raw Versus Exclusive Difference

[MEASURED] FIB raw branch flush and exclusive branch recovery are both 603. Raw I wait is 159, while exclusive I-cache is 157: two raw samples are charged to higher-priority categories.

[MEASURED] Bubble-sort raw load-use is 200, while exclusive dependency is 190. The ten-cycle difference is superseded by higher-priority D-cache/memory wait. Raw I wait is 16, while exclusive I-cache is 15. Raw meanings are unchanged.

[MEASURED] CPU div raw divider wait and exclusive divider block both equal 1,492, preserving directed-stress dominance.

## Calibration Status

### Dependency/load-use

[CALIBRATED MODEL] Bubble-sort is a one-point overlap calibration: `exclusive_dependency = raw_load_use - 10 = 190` cycles. Raw input is 200, precedence prediction is 190, measured exclusive count is 190, and residual is zero by construction. [TBD] A per-hazard cost is not fitted because there is no independent load-use event denominator.

### Branch recovery

[MEASURED] FIB has 603 exclusive branch-recovery cycles (5.03%). [TBD] No event-times-penalty coefficient is fitted: sampled branch flush is not an independently validated branch-recovery event denominator.

### Divider

[CALIBRATED MODEL] CPU div is a directed validation point: raw divider wait, precedence prediction, and measured exclusive divider block all equal 1,492; residual is zero. [TBD] No per-divide latency is fitted without a trustworthy independent operation count. This is not representative application weighting.

### I-cache and D-cache/memory

[MEASURED] Exclusive I-cache cycles are FIB 157, bubble-sort 15, and CPU div 8, versus accepted raw I-miss observations 19, 2, and 1. [TBD] A universal effective I-cache miss cost is not identifiable from these mixed refill, response, and overlap conditions.

[MEASURED] Bubble-sort alone has representative D-cache behavior: three accepted observations and 26 exclusive memory-wait cycles. [TBD] D-cache cost is unfitted because one point cannot separate accepted-miss cost from other memory-wait behavior.

## Limitations and Recommendation

- Exclusive labels are accounting convention, not physical ground truth.
- `other_unclassified` includes productive and unobservable cycles; it is not a base-cycle or retirement-derived quantity.
- Raw indicators remain available and may overlap.
- Branch and cache coefficients remain TBD; no analytical total-cycle equation or DSE is started.

[RATIONALE] A future phase should add calibration evidence for dependency and branch recovery, then strengthen representative D-cache evidence before any parameter or optimization study. No DSE, P1, or architectural change is authorized by this result.
