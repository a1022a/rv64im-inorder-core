# Load-Use P1 Results

## Provenance

- Source base commit: `e9b27cd17077b7917c6612dae5403e1d1d47d1b6`
- Source base tree: `56407a30556a0018d4ebe8375db4093d120af560`
- Branch: `opt/a2-loaduse-p1`
- Phase 8R observer provenance: frozen commit
  `a3386e568c42f46568170626f0e774441fd21d91`
- Optimization: one-cycle load-hit-use bypass

The behavioral RTL change adds an accepted-request D-cache hit indication,
suppresses the immediate load-use bubble only for that qualified hit, and
bypasses the formatted LSU response into matching EX operands. It adds no
synthesizable register and does not change cache or SRAM organization. A miss
retains the baseline hazard bubble and cache/memory stall behavior.

The `PERFORMANCE_MODEL` ports and dependency observer are simulation-only
observability copied from the frozen Phase 8R implementation. The directed
`LOADUSE_P1_MONITOR` ports are also simulation-only. Neither conditional block
is part of the normal synthesis file-list behavior.

## Functional Gate

- Normal and monitor Verilator lint: PASS
- `make doctor`: PASS
- `make build`: PASS
- Dummy plus DiffTest: PASS
- Smoke: PASS
- Load-use directed test: PASS; 15 hit bypass events, 15 matching operand
  bypass events, and 60 miss hazard events
- I-cache 64-set directed test: PASS
- CPU tests: 33/33 PASS
- Klib tests: 33/33 PASS
- Dedicated klib unit tests: 8/8 PASS
- MicroBench, AM hello, AM RTC, timer128, and directed interrupts: PASS
- Fatal, mismatch, bad-trap, abort, assertion, and non-convergence markers: 0

## Measured Performance

| Workload | Baseline cycles | P1 cycles | Delta | Speedup |
| --- | ---: | ---: | ---: | ---: |
| MicroBench FIB | 11978 | 11978 | 0 | 1.000000 |
| CPU bubble sort | 1860 | 1672 | -188 | 1.112440 |
| GOL128 | 590363 | 463868 | -126495 | 1.272696 |
| GOL256 | 2394963 | 1880884 | -514079 | 1.273318 |

GOL128 checksum is `3844`; GOL256 checksum is `15876`. Both cache counter
invariants and controlled termination checks pass. GOL256 requires
`338.559120 MHz` at 180 generations per second, calculated from the measured
P1 result. The measured GOL results are one cycle above their Phase 8R
counterfactual references and are authoritative for this Gate.

## Dependency And Cache Accounting

| Workload | Load-use stall cycles | Load-hit-use stall cycles | D-cache stall cycles |
| --- | ---: | ---: | ---: |
| MicroBench FIB | 0 | 0 | not sampled by the PC-ROI cache observer |
| CPU bubble sort | 2 | 0 | not sampled by the PC-ROI cache observer |
| GOL128 | 512 | 0 | 17280 |
| GOL256 | 2048 | 0 | 69368 |

All remaining measured load-use stalls are miss-related and all load outcomes
are resolved. GOL cache counter sampled cycles equal ROI cycles exactly.

## Reproduction

```sh
bash scripts/run_loaduse_p1_directed.sh
./scripts/run_loaduse_p1_performance.sh
make regress
```

The I-cache directed test requires the patched local NEMU reference path used
by the qualified run. Outputs are retained under `out/logs/` and
`out/loaduse_p1_perf/`.

No synthesis, PrimeTime, setup/hold characterization, or area measurement was
performed in this Gate. Fresh RFIC synthesis and STA are required before any
timing, hold, SRAM-count, or area conclusion can be made for P1.
