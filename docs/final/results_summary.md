# Final results summary

## Performance

| Workload | Original cycles | Final cycles | Speedup | Checksum |
|---|---:|---:|---:|---:|
| FIB | 11,978 | 11,978 | 1.000000x | n/a |
| Bubble | 1,860 | 1,672 | 1.112440x | n/a |
| GOL128 | 590,363 | 463,868 | 1.272696x | 3844 |
| GOL256 | 2,394,963 | 1,880,884 | 1.273317759x | 15876 |

At 180 generations/s, the required frequency falls from 431.093340 MHz to
338.559120 MHz. The selected implementation target is 500 MHz.

## 500 MHz pre-layout ASIC front-end

| Metric | Result |
|---|---:|
| PT setup WNS | +0.000097 ns |
| PT setup TNS / violations | 0 / 0 |
| Hold WNS | +0.037408 ns |
| Hold TNS / violations | 0 / 0 |
| Load-use direct probe | +0.129794 ns, not in top 20 |
| Final total area | 272,919.319248 |
| Baseline total area | 264,938.885248 |
| Area delta | +3.012179% |
| Power | Not closed |

Allowed claim: 500 MHz pre-layout synthesized ASIC front-end setup/hold
closure. Not claimed: post-route closure, signoff Fmax, silicon/product Fmax,
or full PPA. The missing stages are P&R, CTS, extracted parasitics, post-route
STA, and power closure.
