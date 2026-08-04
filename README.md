# rv64im-inorder-core

`rv64im-inorder-core` is a private GitHub engineering repository for an
in-order, single-issue RV64IM_Zicsr processor core. The implementation and
support status are bounded by the current architecture, verification,
known-issues, and provenance documents.

Current top-level identities:

- Simulation top: `rv64im_core_sim_top`
- Synthesis top candidate: `rv64im_core_top`
- Verilator prefix and executable name: `Vtop`

## Directory Overview

- `rtl/vsrc/`: active RTL sources
- `rtl/filelists/`: simulation, synthesis-intent, and lint filelists
- `sim/csrc/`: Verilator C/C++ simulation harness and DiffTest integration
- `config/`: portable defaults and local configuration example
- `scripts/`: build, smoke, regression, and release helpers
- `tests/`: smoke manifest and repository-local custom tests
- `docs/`: architecture, build, verification, known-issues, and provenance notes
- `models/`: placeholder documentation for future modeling work
- `synth/`: synthesis handoff documentation and draft synthesis scope
- `out/`: ignored generated logs, temporary outputs, and release artifacts

## Build And Verification

Stable commands:

```sh
make doctor
make build
make run TEST=dummy
make smoke
make regress
make release
```

`make doctor`, `make build`, `make run TEST=dummy`, and `make smoke` are the
normal pre-publication gates. `make regress` runs the full retained regression
matrix from `scripts/run_regress.sh`. `make release` creates deterministic
release artifacts under `out/`.

External dependencies are configured through ignored `config/local.mk`:

```make
NEMU_REF_SO := /path/to/riscv64-nemu-ref-patched.so
AM_KERNELS_DIR := /path/to/am-kernels
DEFAULT_DUMMY_IMG := $(AM_KERNELS_DIR)/tests/cpu-tests/build/dummy-riscv64-npc.bin
```

Portable defaults live in `config/default.mk`; machine-local paths should not
be added to public Makefiles or scripts.

## Current Verification Summary

The retained full regression summary from the completed engineering pass is:

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

Do not claim a newer result unless the corresponding command has been run and
the logs are retained.

Repository-local directed interrupt tests cover MTIE gating, MIE gating, MTIP
readback, timer trap entry, `mret`, and simultaneous machine interrupt priority
without modifying NEMU. The ordinary regression flow still uses the configured
NEMU DiffTest reference; that reference has a known `mie` comparison limitation.

## Current Boundaries

Formal synthesis, STA, LEC, PPA evaluation, and performance modeling have not
been run or implemented for this repository. The RAM synthesis strategy for
`S011HD1P_X32Y2D128_BW.sv` remains `TBD`; `rtl/filelists/synth.f` records the
current synthesis-intent scope but does not approve a memory implementation
policy. `mtvec` Vectored mode is not implemented, the integration top currently
ties external interrupt low, and the project does not claim full RISC-V
privileged architecture compliance.

Known issues and provenance are tracked in:

- `docs/known_issues.md`
- `docs/origin_provenance.md`
- `docs/architecture.md`
- `docs/verification.md`

License and public redistribution status are under review. Do not remove
copyright, attribution, or third-party provenance markers without an approved
publication decision.
