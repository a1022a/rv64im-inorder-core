# A2 Phase 9 Branch Predictor DSE Final Summary

## Scope

Phase 9 evaluates whether the frozen A2 baseline justifies a low-complexity
branch-recovery / conditional-predictor P1.

This phase is modeling and simulation observability work only. It does not
implement a functional branch-predictor RTL change and does not claim
architectural retirement metrics.

## Frozen workload baselines

- microbench FIB:
  - ROI cycles: 11,978
  - sampled branch-recovery episodes: 603
  - conditional-direction recovery episodes: 603

- CPU bubble-sort:
  - ROI cycles: 1,860
  - sampled branch-recovery episodes: 105
  - conditional-direction recovery episodes: 104
  - JALR-target recovery episodes: 1

Conditional direction therefore dominates the representative branch-recovery
population.

## P0 predictor calibration

The active P0 conditional predictor is a nominal 1024-entry tagless two-bit
saturating-counter table with valid bits and cold `inst[31]` fallback.

The calibrated `a2-raw-v4` timeline separates:

- lookup
- prediction
- update
- speculative prediction-only transactions
- ROI carry-in update transactions

P0 replay reproduces RTL predictor state and prediction behavior without using
RTL lookup state as a repair source.

### FIB

- pre-ROI warm-up updates: 33,813
- ROI lookup-state mismatches: 0
- ROI prediction mismatches: 0
- resolved predictions: 1,284
- speculative unresolved predictions: 6
- carry-in updates: 0
- modeled resolved direction errors: 603
- sampled conditional recovery episodes: 603

### Bubble-sort

- pre-ROI warm-up updates: 0
- ROI lookup-state mismatches: 0
- ROI prediction mismatches: 0
- resolved predictions: 399
- speculative unresolved predictions: 0
- carry-in updates: 1
- carry-in updates with unknown pre-state: 0
- modeled resolved direction errors: 104
- sampled conditional recovery episodes: 104

Status:

`PRE_ROI_WARMUP_CALIBRATED = PASS`

Run pairs are deterministic.

## Candidate timing qualification

For 512-entry, 1024-entry, and 2048-entry candidate index mappings, the frozen
FIB and bubble-sort traces contain zero cases in which a resolved conditional
lookup aliases an older unresolved conditional update to the same candidate
entry.

Offline candidate modeling therefore has no observed lookup-before-update
same-index ambiguity for these configurations.

The counterfactual model remains bounded by the fact that changing prediction
behavior can change the speculative / wrong-path fetch stream.

## Capacity-only DSE

All candidates retain:

- two-bit saturating counters
- valid bits
- cold `inst[31]` fallback
- P0 update behavior

Results:

| Workload | 512 entries | 1024 entries P0 | 2048 entries |
|---|---:|---:|---:|
| FIB resolved direction errors | 602 | 603 | 603 |
| bubble-sort resolved direction errors | 104 | 104 | 104 |

The 512-entry FIB result improves by only one modeled direction error and one
model-estimated cycle:

- estimated ROI cycles: 11,977
- estimated cycle speedup: 1.0000835x
- minimum Fmax retention: 99.99165%
- maximum tolerable Fmax loss: 0.00835%

The result does not repeat on bubble-sort.

The 2048-entry configuration doubles nominal predictor state relative to P0
without reducing modeled direction errors.

Unsupported final-index warm-up, ROI lookup, prediction, and update access
counts are all zero for all three modeled capacities.

Capacity decision:

`NO_BRANCH_P1_YET`

## P0 direction-error morphology

Capacity and cold-start behavior do not explain the dominant FIB errors.

The dominant FIB PCs show balanced, strongly alternating outcome patterns. For
example, PC `0x80003290` has:

- 248 resolved observations
- 124 taken
- 124 not-taken
- 247 direction transitions
- 124 P0 errors
- 0 cold errors

Its static-majority error count equals the P0 error count, while the
previous-outcome / one-bit diagnostic is worse.

This supports a recurring local outcome pattern and possibly history
correlation rather than a simple capacity or cold-start limitation.

Bubble-sort has different behavior. PC `0x80000058` contributes 84 of 104
direction errors and the one-bit diagnostic improves from 84 to 64 errors,
suggesting locally faster adaptation could help. However, PC `0x80000068`
already matches its static-majority error bound and is worse under the one-bit
diagnostic.

The simple mechanism evidence therefore does not generalize across both frozen
workloads.

## Final Phase 9 decision

`STOP_BRANCH_DSE`

No single low-complexity branch mechanism is justified across both frozen
representative workloads.

No branch predictor RTL P1 is selected.

Further history-correlated prediction mechanisms are outside the approved
low-complexity scope for this phase.

## Modeling boundaries

- branch metrics are sampled/resolved conditional observations, not
  architectural retirement counts;
- modeled direction-error counts are not architectural MPKI;
- candidate cycle results are model estimates, not candidate RTL measurements;
- offline counterfactual replay remains bounded by possible changes to the
  speculative / wrong-path fetch stream;
- no synthesis, STA, or PPA claim is made in Phase 9.

## Closure status

- P0 predictor semantics audit: PASS
- exact P0 replay calibration: PASS
- pre-ROI warm-up calibration: PASS
- candidate timing-hazard audit: PASS
- capacity-only DSE: `NO_BRANCH_P1_YET`
- P0 error morphology: COMPLETE
- final branch decision: `STOP_BRANCH_DSE`
- functional branch RTL P1: NONE
