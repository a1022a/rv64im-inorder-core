# A2 Phase 9 P0 Direction-Error Morphology

This is an offline P0 diagnostic over the calibrated reset, warm-up, and frozen
ROI traces. It reports resolved conditional transactions only; it is neither
an architectural branch metric nor a candidate predictor evaluation.

## Frozen Capacity Audit

The corrected capacity script separately counts unsupported final-index warm-up
updates, ROI lookups, predictions, and updates. All four counts are zero for
512, 1024, and 2048 entries on FIB and bubble-sort. The explicit frozen P0
assertion passes: 1024 entries reproduces 603 FIB and 104 bubble-sort resolved
direction errors. The previous `NO_BRANCH_P1_YET` capacity result is frozen.

## Error Concentration

| Workload | Total errors | 50% PC set | 80% PC set | 90% PC set |
|---|---:|---|---|---|
| FIB | 603 | `0x80003290`, `0x8000336c`, `0x800032a0`, `0x800032dc` | 50% set plus `0x8000337c`, `0x800033bc`, `0x800032b0` | 80% set plus `0x800032ec`, `0x80003390` |
| bubble-sort | 104 | `0x80000058` | `0x80000058` | `0x80000058`, `0x80000068` |

FIB's leading PCs are strictly alternating and balanced. For example,
`0x80003290` has 248 observations, 124 taken and 124 not-taken, 124 errors,
no cold errors, and 247 outcome transitions. Its P0 errors are all warm
`counter=3` T-to-N misses. Its static-majority lower bound is 124 errors, so
simple per-PC bias cannot improve it; the one-bit diagnostic is worse at 247.
The same behavior repeats at the other dominant FIB PCs. This supports a
recurring local outcome pattern and possibly branch-history correlation, not
capacity pressure or cold start.

Bubble-sort is different. `0x80000058` causes 84/104 errors (80.77%) with
mixed runs (86 taken, 104 not-taken; transitions TT=53, NN=72, TN=32, NT=32).
It has one cold error and 83 warm errors. Its static-majority bound is 86,
while the one-bit diagnostic is 64, indicating potential faster local
direction adaptation. But `0x80000068` is strongly taken (171/190) and has
19 errors, exactly its static-majority bound and below its one-bit diagnostic
of 35. No one simple low-complexity change is supported consistently across
both workloads.

## Decision

**`STOP_BRANCH_DSE`.** Capacity gave no cross-workload benefit. FIB's dominant
errors are balanced alternation, for which the tested simple diagnostics do not
show a per-PC bias or one-bit remedy. Bubble's mixed dominant branch suggests
faster adaptation locally, but that evidence conflicts with FIB and does not
justify a cross-workload P1 mechanism. Any history-correlated approach is
beyond the approved low-complexity scope and remains subject to the existing
speculative-stream qualification bound.
