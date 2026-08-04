# Verification

Phase 6 full regression command:

```sh
make regress > out/logs/phase6/make-regress.retry3.log 2>&1
```

Exit status: `0`

Retained summary:

- CPU tests: `33/33 PASS`
- CPU-style tests linked with klib: `33/33 PASS`
- Dedicated klib unit tests: `8/8 PASS`
- MicroBench: `PASS`
- AM hello: `PASS`
- AM RTC: `PASS`
- timer128 interrupt and mret: `PASS`
- DiffTest fatal markers: `0`
- bad trap: `0`
- abort: `0`
- assertion failure: `0`
- non-convergence marker: `0`

Primary logs:

- `out/logs/phase6/make-regress.retry3.log`
- `out/logs/regress/summary.txt`
- Per-image logs under `out/logs/regress/`

The timer128 test is repository-local and built under `out/regress/` by
`scripts/run_regress.sh`. External NEMU and am-kernels paths are read from local
configuration; the regression does not modify those external projects.

The full regression matrix is maintained in `scripts/run_regress.sh`. The
former placeholder `tests/manifests/regress.txt` is not part of the active
`make regress` path.

Directed machine interrupt checks are implemented by
`scripts/run_intr_directed.sh`. They use a repository-local Verilator testbench
for MTIE gating, MIE gating, MTIP readback, trap-entry `mstatus` updates,
`mret`, and external/software/timer priority. The tests do not modify NEMU; the
existing NEMU reference remains used by the ordinary CPU, klib, MicroBench, AM,
and timer128 regression paths.
