# Custom Tests

This directory is reserved for repository-local custom tests.

`add4to2_unit.sv` is a standalone, deterministic I/O test for the synthesis-
listed `rv64im_core_add_4to2` block, which is not instantiated by the active
CPU hierarchy. Run it with `scripts/run_add4to2_unit.sh`; it exhaustively tests
the 4-bit configuration and tests directed plus fixed-seed random 8-bit vectors.

Phase 6 adds `timer128_interrupt_mret.S`, a bare-metal test assembled by
`scripts/run_regress.sh`. It programs CLINT `mtimecmp`, enables machine global
interrupts with `mstatus.MIE`, checks timer interrupt `mcause`, writes `mepc`,
executes `mret`, and exits through the existing ebreak trap convention.

`loaduse_p1_directed.S` checks immediate load-hit-use forwarding for every
implemented RV64 load width, both operands, branches, stores, x0, cold misses,
refills, and dirty evictions. Run it with `bash scripts/run_loaduse_p1_directed.sh`.
