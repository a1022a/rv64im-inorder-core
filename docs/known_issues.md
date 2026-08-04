# Known Issues

Phase 0 issue log. No source files were changed to address these issues.

## Highest Risk Items

- Before Phase 1 fixes the legacy Makefile, do not run `make comp`, `make run`, or `make gdb`; these targets can automatically create Git commits.
- Legacy Makefile targets create Git commits as build side effects.
- Parent `../Makefile` `git_commit` stages `..`, which is an unsafe boundary for an engineered sub-repository.
- Current Git history contains legacy commits before baseline `59bcac3`; this history must not be pushed directly to GitHub.
- `rv64im_core_sim_top` is simulation-only but is the current Verilator top.
- `rv64im_core_top` is the synthesis top candidate; `rtl/filelists/synth.f` records the current synthesis-intent scope, but RAM synthesis strategy is still `TBD`.
- `rv64im_core_ram` instantiates behavioral RAM model `S011HD1P_X32Y2D128_BW`; a synthesis filelist cannot simply remove that module and be considered complete.
- C++ simulation depends on generated class `Vtop`, public top ports, and DPI function names.
- DiffTest commit, interrupt, and device skip behavior depends on `rv64im_core_sim_top` internal hierarchy probes and must be preserved during rename/migration.
- Backup file `rtl/vsrc/exu/zrv_booth_mul.sv.before_split_var_20260802` defines duplicate legacy module `zrv_booth_mul`; active filelists exclude it, and future source discovery must keep it excluded.

## Build-System Issues

- `commit`, `comp`, `run`, and `gdb` call `git_commit`.
- Default `make` target is `commit`, not build, doctor, or help.
- `include ../Makefile` creates dependency on parent workbench policy and identity values.
- Machine-local path `/home/icer/ysyx-workbench/nemu/build` is embedded in `Makefile`.
- Legacy Makefile default DiffTest reference path differs from the documented verified baseline reference model; do not claim they are equivalent.
- Phase 1 must make the verified reference model path explicit through machine-local configuration.
- `CFLAGS` uses `-I../csrc/include`, which currently resolves from `build/` back to local `csrc/include`; this becomes fragile when `OBJ_DIR` or directory layout changes.
- `docs/history/filelists/legacy_zrv.f` is not used by current Verilator build.
- Verilator source ordering comes from shell `find`.
- Build output goes to `build/`, while final target layout prefers `out/`.
- `clean` removes `build/` and root `*.vcd`; it does not model future `out/` layout yet.

## Filelist Issues

- `docs/history/filelists/legacy_zrv.f` mixes simulation top `rv64im_core_sim_top` and synthesis top `rv64im_core_top`.
- `docs/history/filelists/legacy_zrv.f` includes behavioral RAM and therefore cannot be promoted to a complete synthesis filelist without an explicit RAM policy.
- `docs/history/filelists/legacy_zrv.f` is missing an explicit comment boundary for simulation-only content.
- `rv64im_core_defines.sv` appears after files that include it; current operation relies on include search path rather than filelist ordering.
- `rtl/filelists/sim.f` includes the simulation top `rv64im_core_sim_top`, `rv64im_core_top`, and the behavioral RAM model required for current Verilator validation.
- `rtl/filelists/synth.f` excludes `rv64im_core_sim_top`, DPI-only logic, C/C++ sources, generated files, and backup files.
- `rtl/filelists/lint.f` includes active RTL for static checks, including `rv64im_core_sim_top`, while excluding backup files and generated content.
- RAM synthesis strategy for `S011HD1P_X32Y2D128_BW.sv` remains `TBD`; no SRAM macro, black-box, or behavioral RAM synthesis policy has been selected.

## RTL Boundary Issues

- `rv64im_core_sim_top` imports DPI functions and references deep internal hierarchy under `u_rv64im_core_top.u_rv64im_core_core`.
- `rv64im_core_sim_top` computes `wb_sign`, `wb_pc`, `wb_inst`, `wb_intr`, `intr_num`, `wb_device`, `st_addr`, and `st_data` for C++/DiffTest.
- `rv64im_core_top` has no DPI imports observed and exposes AXI-style ports, but synthesis readiness is not verified.
- `rv64im_core_Nto1`, `rv64im_core_add_4to2`, and `rv64im_core_cla_4` have no active instantiation observed in Phase 0 search; keep until lint/synthesis confirms status.
- Simplified AXI implementation is not yet characterized as a fully general high-concurrency AXI4 implementation.

## C/C++ Simulation Issues

- `sim/csrc/sim_main.cpp` directly includes generated `Vtop.h` and `Vtop__Dpi.h`.
- `sim/csrc/sim_main.cpp` constructs `Vtop` and directly drives `clk`/`rstn`.
- `sim/csrc/sim_main.cpp` reads top ports `wb_sign`, `wb_pc`, `wb_inst`, `wb_intr`, `intr_num`, and `wb_device`.
- Waveform output is hard-coded as `wave.vcd`.
- Log output path is command-line controlled, defaulting to stdout.
- DiffTest requires a NEMU shared object from a machine-local path unless overridden; the verified baseline path and legacy Makefile default path differ.

## Identifier Cleanup Classification

Completed in active sources:

- Project-internal active RTL/module/file prefix names use `rv64im_core_*`.
- Project-internal active macro prefix names use `RV64IM_CORE_*`.
- Active simulation top is `rv64im_core_sim_top`.
- Active synthesis top candidate is `rv64im_core_top`.

Preserved legacy contexts:

- `docs/history/filelists/legacy_zrv.f` is a legacy audit artifact, is not used
  by the stable build, and is excluded from publication release artifacts.
- Backup file `rtl/vsrc/exu/zrv_booth_mul.sv.before_split_var_20260802` is preserved and excluded from active filelists.

Must preserve:

- Historical `docs/history/*` provenance.
- External environment names such as `ysyx-workbench`, NEMU, Abstract Machine, am-kernels, and ysyxSoC.
- Copyright, license, author, and source attribution text.
- Parent-tracer metadata in old Git commits as historical evidence.

Generated or local-only:

- `build/`, `out/`, `sim/csrc/cscope.*`, `sim/csrc/tags`, `rtl/vsrc/.project`, `rtl/vsrc/.library_mapping.xml`, `rtl/vsrc/.settings/*`.

## Backup File Status

- `sim/csrc/include/config.h.bak`: no active build, filelist, include, or source reference found. Keep preserved and excluded unless a later approved cleanup decides otherwise.
- `rtl/vsrc/exu/zrv_booth_mul.sv.before_split_var_20260802`: no active Makefile source discovery, filelist, or source include reference found. Active filelists exclude it because it defines duplicate legacy module `zrv_booth_mul`. Keep preserved and excluded unless a later approved cleanup decides otherwise.

## Architecture TBDs

- Exact public ISA claim beyond observed decode remains TBD until instruction tests are mapped to decode coverage.
- Privilege support beyond observed machine-mode CSR path remains TBD.
- RAM strategy remains unresolved; until it is approved, `synth.f` should be marked draft or not fully elaboratable.
- Architecture facts in Phase 0 documents are source-audit observations only; no post-refactor state may be marked PASS without actually running and retaining the corresponding command output.
- Final `sim/include` versus `sim/csrc/include` include layout remains a low-risk structural choice, but should be approved before migration.
- Final clean GitHub history strategy remains TBD, but current history should not be pushed directly.

## Verification Infrastructure Context

- Attached context from the prior task indicates a verification-side owner/provenance mapping issue around activation tracing, not a Phase 0 source change.
- That issue is outside Phase 0 implementation scope and should be recorded for later verification-infrastructure work only.
- The configured NEMU reference model supports the CSR subset required by the
  current DiffTest flow (`mstatus`, `mtvec`, `mepc`, `mcause`, `mtval`). The
  Phase 6 custom timer128 test avoids unsupported `mie` CSR access because the
  DUT timer interrupt gate uses `mstatus.MIE` plus the CLINT interrupt request.
- Directed machine interrupt tests exercise MTIE gating, MIE gating, MTIP
  readback, trap-entry state, `mret`, and simultaneous asynchronous interrupt
  priority without modifying NEMU.
- `mtvec` Vectored mode is not implemented; current trap redirection uses the
  aligned Direct-mode base address.
- The current integration top ties the external interrupt source low, so
  external interrupt priority is verified by the directed interrupt-controller
  test rather than by a full SoC-level external interrupt source.
- The project does not claim full RISC-V privileged architecture compliance.
