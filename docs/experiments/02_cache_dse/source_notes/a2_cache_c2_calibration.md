# A2 Cache C2 Calibration

All raw traces start at reset and contain both PRE_ROI warm-up and the existing
C1 ROI. The 8 KiB replay uses four ways, 32-byte lines, 64 sets, and the exact
RTL tree-PLRU/state-update semantics. Every accepted access was compared with
the recorded RTL hit, miss, and dirty-eviction outcome; all comparisons pass.

| Workload | PRE_ROI accesses | ROI accesses | RTL misses | Replay misses | RTL WB | Replay WB |
|---|---:|---:|---:|---:|---:|---:|
| FIB | 57,143 | 2,153 | 0 | 0 | 0 | 0 |
| bubble-sort | 6 | 589 | 3 | 3 | 0 | 0 |
| GOL128 | 36,738 | 158,760 | 1,016 | 1,016 | 1,016 | 1,016 |
| GOL256 | 147,202 | 645,160 | 4,080 | 4,080 | 4,080 | 4,080 |

Trace self-checks enforce contiguous sequence numbers, nondecreasing simulator
cycles, a single PRE_ROI-to-ROI transition, legal 32-bit addresses, LOAD/STORE
operations, 8-bit masks, and consistent one-hot RTL hit/miss outcomes. Replay
enforces `hits + misses = accesses`, power-of-two sets, and valid way indices.

`CACHE_REPLAY_BASELINE_CALIBRATION=PASS`

`RTL_OUTCOME_PER_ACCESS_CHECK=PASS`
