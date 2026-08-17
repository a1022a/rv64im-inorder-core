# A2 Load-Use Baseline Profile

Raw JSON and the primary CSV remain under
`${LOCAL_HOME}/rv64im-loaduse-model-scratch/results`.

| Workload | ROI cycles | dependency cycles/episodes | load-use | hit-use | miss-related | MUL |
|---|---:|---:|---:|---:|---:|---:|
| FIB | 11,978 | 224 / 224 | 0 | 0 | 0 | 224 |
| bubble-sort | 1,860 | 190 / 190 | 190 | 188 | 2 | 0 |
| GOL128 | 590,363 | 127,008 / 127,008 | 127,008 | 126,496 | 512 | 0 |
| GOL256 | 2,394,963 | 516,128 / 516,128 | 516,128 | 514,080 | 2,048 | 0 |

All four new exclusive dependency counts exactly match the frozen old
attribution. GOL128 reproduces checksum 3844 and GOL256 reproduces 15876. Every
episode is one cycle. GOL256's dependency/load-use share is 21.550563%; hit-use
alone is 21.465050%.

GOL256 contains only eight static producer PCs and eight corresponding consumer
PCs. Each pair contributes 64,516 episodes, so the behavior is a small set of
very hot load/consumer pairs rather than diffuse dependencies.

FIB is the critical correction to the earlier coarse interpretation: its 224
cycles are all multiply-to-consumer dependencies. A load-use mechanism has zero
qualified FIB opportunity.
