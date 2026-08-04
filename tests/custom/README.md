# Custom Tests

This directory is reserved for repository-local custom tests.

Phase 6 adds `timer128_interrupt_mret.S`, a bare-metal test assembled by
`scripts/run_regress.sh`. It programs CLINT `mtimecmp`, enables machine global
interrupts with `mstatus.MIE`, checks timer interrupt `mcause`, writes `mepc`,
executes `mret`, and exits through the existing ebreak trap convention.
