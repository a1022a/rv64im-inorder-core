# A2 Load-Use Counterfactual Model

The model reports sensitivity bounds, not RTL predictions.

`PERFECT_DEPENDENCY` removes every exclusive dependency cycle and is only a
broad mathematical ceiling. `PERFECT_LOAD_USE` removes only qualified true
load-use cycles. `ONE_CYCLE_LOAD_HIT` removes at most one cycle per qualifying
hit-use episode: `min(hit-use cycles, hit-use episodes)`.

| Workload | perfect dependency | perfect load-use | one-cycle hit-use |
|---|---:|---:|---:|
| FIB | 1.019057x | 1.000000x | 1.000000x |
| bubble-sort | 1.113772x | 1.113772x | 1.112440x |
| GOL128 | 1.274105x | 1.274105x | 1.272699x |
| GOL256 | 1.274706x | 1.274706x | 1.273318x |

For GOL256, perfect load-use reduces the sensitivity cycle count to 1,878,835
and the one-cycle hit-use case to 1,880,883. At 180 generations/s these imply
338.190300 MHz and 338.558940 MHz respectively, versus the measured baseline
requirement of 431.093340 MHz.

These values assume removed bubbles do not expose a new structural, cache,
control, or timing limit. No combinational bypass feasibility is implied.
