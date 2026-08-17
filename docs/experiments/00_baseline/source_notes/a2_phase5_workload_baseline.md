# A2 Phase 5 Workload Baseline

## Scope and rules

This baseline is measured on `modeling/a2-performance-v1` at
`fd9440d74c38c1c341fa130cd85a6a8abd2fa49a`, whose A2 base is
`df956d23cc420b761104f359792cfbd5bb5e4747`. Each workload ran twice with
identical raw JSON. Both runs reached `HIT GOOD TRAP`, had JSON
`exit_status = 0`, and had no ASan, DiffTest, abort, assertion, or
non-convergence failure.

`wb_sign` remains a `PARTIAL_RETIREMENT_EVENT`. Therefore
`wb_observation_count` is an observation, not an architectural retired
instruction count. This document does not report retired instructions, IPC,
CPI, retired loads/stores, or MPKI. `jalr_target_error_count` is a held-level
provisional raw signal and is not interpreted as a JALR-target-misprediction
event or used for bottleneck ranking.

Occupancy ratios below are raw sampled-level occupancy divided by ROI cycles.
They can overlap and are neither CPI contributions nor additive.

## Workloads and ROI semantics

| Workload | Classification | ROI start | ROI end | Semantic boundary |
|---|---|---|---|---|
| `microbench_fib` | Representative workload kernel; branch-heavy compute | `0x80003150` | `0x80004a94` | `bench_fib_run` entry through the instruction in `main` immediately after its indirect call returns; excludes timing/device work, validation, reporting, and termination. |
| `cpu_bubble_sort` | Workload kernel; memory/dependency candidate | `0x80000028` | `0x800000a0` | First `bubble_sort` call on the initially unsorted array through `main`'s first validation instruction after the return; excludes checks, second already-sorted invocation, and termination. |
| `cpu_div` | Directed/synthetic divider stress point | `0x800000a0` | `0x800000c0` | Nested `divw` loop entry through the first validation-setup instruction after all ten array elements complete; excludes initialization, multiply loop, checks, and termination. |

The original FIB end candidate `0x800033e0` was rejected: it is a conditional
path jump within `bench_fib_run`, not a normal-completion boundary. Normal
execution returns at `0x8000331c` and reaches `0x80004a94` in `main`.

## Reproducibility and raw baseline

All three points had `roi_valid = true`; run 1 and run 2 JSON were bytewise
equal for the measured fields, including the observation arrays.

| Raw observation | FIB | CPU bubble-sort | CPU div |
|---|---:|---:|---:|
| ROI cycles | 11,978 | 1,860 | 1,883 |
| Writeback observations | 9,787 | 1,314 | 340 |
| Branch-resolved observations | 1,314 | 401 | 110 |
| Branch-direction-error observations | 603 | 104 | 11 |
| I-cache miss observations | 19 | 2 | 1 |
| D-cache miss observations | 0 | 3 | 0 |
| I-cache wait cycles | 159 | 16 | 8 |
| D-cache/memory wait cycles | 0 | 26 | 0 |
| Load-use stall cycles | 224 | 200 | 0 |
| Divider wait cycles | 0 | 0 | 1,492 |
| Flush observations | 827 | 295 | 11 |
| Branch-flush observations | 603 | 105 | 11 |

## Safe derived ratios

| Ratio or rate | FIB | CPU bubble-sort | CPU div |
|---|---:|---:|---:|
| Branch direction-error ratio | 45.89% | 25.94% | 10.00% |
| I-cache wait occupancy | 1.33% | 0.86% | 0.42% |
| D-cache/memory wait occupancy | 0.00% | 1.40% | 0.00% |
| Load-use stall occupancy | 1.87% | 10.75% | 0.00% |
| Divider wait occupancy | 0.00% | 0.00% | 79.24% |
| I-cache miss observations per 1K ROI cycles | 1.586 | 1.075 | 0.531 |
| D-cache miss observations per 1K ROI cycles | 0.000 | 1.613 | 0.000 |

## Characterization and candidate ranking

FIB is branch-heavy compute: it has the highest branch-direction-error ratio
and branch-flush observations, while D-cache/memory wait is absent. Its
load-use and I-cache occupancies are present but low.

CPU bubble-sort is not D-cache/memory dominated in this small existing test.
It does exercise D-cache/memory behavior (three accepted miss observations and
1.40% wait occupancy), but its largest measured occupancy is load-use/dependency
stall at 10.75%. It is therefore a useful dependency-oriented workload-kernel
point with secondary D-cache behavior, rather than evidence for a memory-first
conclusion.

CPU div is a directed divider stress point, not a representative application
workload. Its 79.24% divider-wait occupancy validates that the selected loop
isolates the intended mechanism.

Across this deliberately small P0 set, measured candidate modeling targets
rank as follows:

1. Divider wait: strongest isolated occupancy in the directed CPU-div point.
2. Dependency/load-use stall: strongest representative-kernel occupancy in
   CPU bubble-sort.
3. Branch prediction/recovery: strongest branch-direction-error ratio and
   branch flush evidence in FIB.
4. I-cache: present at low occupancy in every point.
5. D-cache/memory: exercised only by bubble-sort and below dependency
   occupancy there.

This ranks observed modeling targets only; it does not select an RTL P1
optimization, construct an analytical cycle equation, or begin DSE.

## Limitations

- Raw occupancy indicators may overlap or mask one another.
- Cache miss fields are accepted raw observations, not transaction-normalized
  architectural metrics.
- The workload set is intentionally limited to the existing shortlisted FIB,
  CPU bubble-sort, and CPU-div points.
- `jalr_target_error_count` is omitted from headline analysis until its
  held-level event semantics are independently resolved.
