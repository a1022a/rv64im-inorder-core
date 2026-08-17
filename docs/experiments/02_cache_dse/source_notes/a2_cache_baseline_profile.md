# A2 Baseline Cache Profile

Raw JSON/CSV lives under `${LOCAL_HOME}/rv64im-cache-model-scratch`. IPC and MPKI
are not reported because retirement is not qualified.

| Workload | cycles | I access/miss/rate | I stall (exclusive) | D access/miss/rate | D stall (exclusive) | WB |
|---|---:|---:|---:|---:|---:|---:|
| FIB | 11,978 | 10,994 / 19 / 0.1728% | 159 (157) | 2,153 / 0 / 0% | 0 (0) | 0 |
| bubble-sort | 1,860 | 1,524 / 2 / 0.1312% | 16 (15) | 589 / 3 / 0.5093% | 26 (26) | 0 |
| GOL128 | 590,363 | 441,853 / 8 / 0.00181% | 64 (55) | 158,760 / 1,016 / 0.6400% | 17,280 | 1,016 |
| GOL256 | 2,394,963 | 1,792,893 / 8 / 0.000446% | 64 (55) | 645,160 / 4,080 / 0.6324% | 69,368 | 4,080 |

GOL128 and GOL256 exactly reproduced 590,363/3844 and 2,394,963/15876.
For GOL256, D refill is 32,648 cycles and writeback is 36,720 cycles; their
non-overlapping union is 69,368 cycles (2.8964%). I$ contributes 55 exclusive
cycles. Dependency remains much larger at 516,128 cycles.

`DCACHE_BOTTLENECK_EVIDENCE=WEAK`; `ICACHE_BOTTLENECK_EVIDENCE=NONE`.
The working-set ratios motivate C2 analysis but do not establish a bottleneck.
