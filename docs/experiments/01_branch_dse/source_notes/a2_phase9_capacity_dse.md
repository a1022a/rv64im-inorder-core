# A2 Phase 9 Conditional Predictor Capacity DSE

This is an offline model sweep over frozen `a2-raw-v4` warm-up and ROI traces.
It changes no RTL, does not measure candidate execution, and remains bounded by
the observed P0 speculative stream.

## Method

`models/sweep_conditional_predictor_capacity.py` initializes each candidate
from reset, trains with ordered `predictor_warmup_updates`, then processes the
captured ROI lookup/prediction/update order. All candidates retain P0's two-bit
saturating counters, valid bits, cold `inst[31]` fallback, and update rule.
The final index of each candidate table is unsupported because the current RTL
uses `i < DEPTH-1`; any warm-up or ROI access to that index invalidates the
candidate result. None occurred.

## Results

| Workload | Entries | State bits | Warm-up updates | Unsupported accesses | Resolved errors | Delta vs P0 |
|---|---:|---:|---:|---:|---:|---:|
| FIB | 512 | 1,536 | 33,813 | 0 | 602 | -1 |
| FIB | 1,024 | 3,072 | 33,813 | 0 | 603 | 0 |
| FIB | 2,048 | 6,144 | 33,813 | 0 | 603 | 0 |
| bubble-sort | 512 | 1,536 | 0 | 0 | 104 | 0 |
| bubble-sort | 1,024 | 3,072 | 0 | 0 | 104 | 0 |
| bubble-sort | 2,048 | 6,144 | 0 | 0 | 104 | 0 |

The 512-entry FIB result is a one-error improvement (0.1658%), giving a
**model estimate** of 11,977 cycles, one cycle saved, and 1.0000835x speedup.
It requires retaining more than 99.99165% of P0 Fmax (maximum 0.00835% loss).
All other configurations have zero estimated cycle change and therefore no
positive Fmax-loss budget. Bubble-sort is invariant across all three sizes.

## Decision

**`NO_BRANCH_P1_YET`.** The sole FIB one-cycle modeled improvement does not
repeat on bubble-sort and is too small to justify an RTL capacity change or
lookup-timing risk. Doubling to 2,048 entries doubles nominal state without
benefit. The remaining qualification bound is material: a changed predictor
can change speculative/wrong-path fetch behavior, which this P0-stream replay
does not re-execute.
