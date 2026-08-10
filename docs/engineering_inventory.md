# Engineering Inventory

Phase 0 only. This document records observed repository facts before any
engineering refactor.

## Environment

- Repository workspace: `/home/icer/ysyx-workbench/rv64im-inorder-core`
- Hostname: `myliunx`
- `pwd`: `/home/icer/ysyx-workbench/rv64im-inorder-core`
- Git root: `/home/icer/ysyx-workbench/rv64im-inorder-core`
- Current branch: `refactor/engineering-v1`
- Git status before Phase 0 edits: clean
- Functional baseline commit: `59bcac3 chore: import verified functional baseline`
- Functional baseline tag: `v0.1.0-functional-baseline`
- Tag ref observed: `6b1de1a46ff880d71d17f940cb2f14908c1ece6d refs/tags/v0.1.0-functional-baseline`
- Current HEAD during audit: `2cce9ab chore: add Codex engineering guardrails`

## Repository Categories

- RTL source: `vsrc/**/*.sv`
- RTL global definitions: `vsrc/rv64im_core_defines.sv`
- Simulation RTL top: `vsrc/rv64im_core_sim_top.sv`
- Synthesis RTL top candidate: `vsrc/rv64im_core_top.sv`
- Behavioral RAM model: `vsrc/units/S011HD1P_X32Y2D128_BW.sv`
- C/C++ simulation source: `csrc/*.c`, `csrc/*.cc`, `csrc/*.cpp`
- C/C++ simulation headers: `csrc/include/*`
- Build entry: `Makefile`
- Filelist: `zrv.f`
- Historical documents: `docs/history/*`
- Backup files: `csrc/include/config.h.bak`, `vsrc/exu/zrv_booth_mul.sv.before_split_var_20260802`
- IDE/index files: `vsrc/.project`, `vsrc/.library_mapping.xml`, `vsrc/.settings/*`, `csrc/cscope.*`, `csrc/tags`
- Build outputs: `build/*`, `out/*`, generated `Vtop*`, object/archive/dependency files, waveform/log files

## Makefile Audit

Variables:

- `TOPNAME=rv64im_core_sim_top`
- `TOP_CLASS_NAME=Vtop`
- `INCLUDE_PATH=./vsrc`
- `OBJ_DIR=build`
- `LIBS=/home/icer/ysyx-workbench/nemu/build`
- `VSRCS=$(shell find ./vsrc -name "*.*v")`
- `CSRCS=$(shell find ./csrc -name "*.c" -or -name "*.cc" -or -name "*.cpp")`
- `IMG?=`
- `ARGS?=`, extended with `-d $(LIBS)/riscv64-nemu-interpreter-so` and `-b`
- `CFLAGS=-I../csrc/include -ggdb -O2`
- `CFLAGS += $(shell llvm-config --cxxflags) -fPIE`
- `LDFLAGS=-lLLVM-12 -lreadline -ldl -pie -fsanitize=address -lSDL2`

Included parent Makefile:

- Current `Makefile` executes `include ../Makefile`.
- Parent `../Makefile` defines `STUID=ysyx_22040735`, `STUNAME=zz1E1E`, `git_commit`, and `_default`.
- `git_commit` runs `git add .. -A --ignore-errors`, waits for `.git/index.lock`, then creates an allow-empty commit using author `tracer-ysyx2204 <tracer@ysyx.org>`.
- Because the include is from the parent directory, legacy `commit`, `comp`, `run`, and `gdb` targets can stage paths outside this project root if run from a nested workspace arrangement. In this repository snapshot the Git root is current directory, but the command text is still unsafe engineering-wise.

Targets:

- Default target: `commit`, because it is the first explicit target in this Makefile.
- `commit`: invokes `$(call git_commit, "commit NPC")`.
- `all`: depends on `clean comp run`.
- `comp`: depends on `commit`; invokes another `git_commit` with `"comp NPC"`; then runs Verilator.
- `run`: depends on `comp`; invokes `git_commit` with `"run NPC"`; then runs `./build/Vtop $(ARGS) $(IMG)`.
- `gdb`: depends on `comp`; invokes `git_commit` with `"gdb NPC"`; then runs `gdb --args ./build/Vtop $(ARGS) $(IMG)`.
- `wave`: runs `gtkwave ./wave.vcd`.
- `clean`: runs `rm -rf ./build *.vcd`.

Verilator command:

- `verilator --cc --trace --exe --build $(CSRCS) $(VSRCS) -I$(INCLUDE_PATH) -top $(TOPNAME) --prefix $(TOP_CLASS_NAME) --Mdir $(OBJ_DIR) $(addprefix -CFLAGS , $(CFLAGS)) $(addprefix -LDFLAGS , $(LDFLAGS))`
- Verilator top module: `rv64im_core_sim_top`
- Generated class/prefix: `Vtop`
- Include path: `./vsrc`
- Build output directory: `build`
- Source discovery is `find` based, not filelist based.

Makefile engineering risks:

- Build targets create Git commits as side effects.
- Parent Makefile stages `..`, which is too broad for this project.
- `CFLAGS` include path is `../csrc/include`; this is relative to Verilator's `build/` compilation directory and currently resolves back to local `csrc/include`, but it is fragile under output-directory migration.
- `LIBS` is a machine-local absolute NEMU path; the exact legacy and verified reference model paths are recorded in the DiffTest section below.
- Verilator source order comes from `find`; ordering is not explicit.
- `zrv.f` is not used by the current Verilator build.
- `clean` uses `rm -rf ./build *.vcd` and removes only legacy `build/` plus root waveforms.
- Generated files currently go to `build/`, while the target layout says generated files should go under `out/` where practical.

## zrv.f Audit

`zrv.f` contains 37 entries in this order:

1. `./vsrc/bus/rv64im_core_1toN.sv`
2. `./vsrc/bus/rv64im_core_2to1.sv`
3. `./vsrc/bus/rv64im_core_AtoB.sv`
4. `./vsrc/bus/rv64im_core_axi.sv`
5. `./vsrc/bus/rv64im_core_clint.sv`
6. `./vsrc/bus/rv64im_core_Nto1.sv`
7. `./vsrc/cache/rv64im_core_dcache.sv`
8. `./vsrc/cache/rv64im_core_ram.sv`
9. `./vsrc/core/rv64im_core_core.sv`
10. `./vsrc/core/rv64im_core_pipe_ctrl.sv`
11. `./vsrc/exu/rv64im_core_alu.sv`
12. `./vsrc/exu/rv64im_core_booth_mul.sv`
13. `./vsrc/exu/rv64im_core_csr_reg.sv`
14. `./vsrc/exu/rv64im_core_div.sv`
15. `./vsrc/exu/rv64im_core_exu.sv`
16. `./vsrc/exu/rv64im_core_id_alu.sv`
17. `./vsrc/exu/rv64im_core_intr_ctrl.sv`
18. `./vsrc/idu/rv64im_core_id.sv`
19. `./vsrc/idu/rv64im_core_idu.sv`
20. `./vsrc/idu/rv64im_core_if_id.sv`
21. `./vsrc/idu/rv64im_core_regfile.sv`
22. `./vsrc/ifu/rv64im_core_ifu.sv`
23. `./vsrc/ifu/rv64im_core_ras.sv`
24. `./vsrc/ifu/rv64im_core_satcnt.sv`
25. `./vsrc/mem/rv64im_core_ls.sv`
26. `./vsrc/mem/rv64im_core_lsu.sv`
27. `./vsrc/units/S011HD1P_X32Y2D128_BW.sv`
28. `./rtl/vsrc/units/rv64im_core_add4to2.sv`
29. `./rtl/vsrc/units/rv64im_core_add_full.sv`
30. `./rtl/vsrc/units/rv64im_core_cla4.sv`
31. `./rtl/vsrc/units/rv64im_core_compress_34to2.sv`
32. `./vsrc/units/rv64im_core_reg.sv`
33. `./vsrc/wb/rv64im_core_wb.sv`
34. `./vsrc/wb/rv64im_core_wbu.sv`
35. `./vsrc/rv64im_core_defines.sv`
36. `./vsrc/rv64im_core_sim_top.sv`
37. `./vsrc/rv64im_core_top.sv`

Filelist observations:

- It includes both `rv64im_core_sim_top` and `rv64im_core_top`.
- It includes `S011HD1P_X32Y2D128_BW.sv`, a behavioral RAM model used by `rv64im_core_ram`.
- It does not include C/C++ sources.
- It does not include backup files.
- It is suitable as a legacy simulation-oriented RTL list.
- It is not suitable as a direct synthesis filelist because it includes simulation top `rv64im_core_sim_top`, DPI imports, and the unresolved behavioral RAM model.
- `rv64im_core_defines.sv` appears late in the filelist, while most RTL files textually include it through `-I./vsrc`; current Verilator build uses `find`, not `zrv.f`.

## RTL Modules

- `rtl/vsrc/units/rv64im_core_add_full.sv`: module `rv64im_core_add_full`; instantiated by `rv64im_core_add_4to2` and `rv64im_core_compress_34to2`.
- `rtl/vsrc/units/rv64im_core_add4to2.sv`: module `rv64im_core_add_4to2`; no direct instantiation observed in active RTL search.
- `vsrc/units/rv64im_core_reg.sv`: module `rv64im_core_reg`; instantiated throughout pipeline registers, CSR, CLINT, and simulation counters.
- `rtl/vsrc/units/rv64im_core_compress_34to2.sv`: module `rv64im_core_compress_34to2`; instantiated by `rv64im_core_booth_mul`.
- `rtl/vsrc/units/rv64im_core_cla4.sv`: module `rv64im_core_cla_4`; no direct instantiation observed in active RTL search.
- `vsrc/units/S011HD1P_X32Y2D128_BW.sv`: module `S011HD1P_X32Y2D128_BW`; instantiated by `rv64im_core_ram`.
- `vsrc/exu/rv64im_core_exu.sv`: module `rv64im_core_exu`; instantiates `rv64im_core_reg`, `rv64im_core_id_alu`, `rv64im_core_alu`, `rv64im_core_csr_reg`, `rv64im_core_intr_ctrl`; instantiated by `rv64im_core_core`.
- `vsrc/exu/rv64im_core_intr_ctrl.sv`: module `rv64im_core_intr_ctrl`; instantiated by `rv64im_core_exu`.
- `vsrc/exu/rv64im_core_div.sv`: module `rv64im_core_div`; instantiated by `rv64im_core_alu`.
- `vsrc/exu/rv64im_core_csr_reg.sv`: module `rv64im_core_csr_reg`; instantiated by `rv64im_core_exu`.
- `vsrc/exu/rv64im_core_booth_mul.sv`: module `rv64im_core_booth_mul`; instantiates `rv64im_core_compress_34to2`; instantiated by `rv64im_core_alu`.
- `vsrc/exu/rv64im_core_alu.sv`: module `rv64im_core_alu`; instantiates `rv64im_core_div` and `rv64im_core_booth_mul`; instantiated by `rv64im_core_exu`.
- `vsrc/exu/rv64im_core_id_alu.sv`: module `rv64im_core_id_alu`; instantiates `rv64im_core_reg`; instantiated by `rv64im_core_exu`.
- `vsrc/cache/rv64im_core_ram.sv`: module `rv64im_core_ram`; instantiates `S011HD1P_X32Y2D128_BW`; instantiated by `rv64im_core_dcache`.
- `vsrc/cache/rv64im_core_dcache.sv`: module `rv64im_core_dcache`; instantiates four `rv64im_core_ram` banks per generate block; instantiated twice by `rv64im_core_top` as D-cache and I-cache.
- `vsrc/rv64im_core_top.sv`: module `rv64im_core_top`; instantiates `rv64im_core_1toN`, `rv64im_core_AtoB`, `rv64im_core_2to1`, `rv64im_core_core`, `rv64im_core_clint`, two `rv64im_core_dcache` instances, and `rv64im_core_axi_rw`; intended synthesis top.
- `vsrc/rv64im_core_sim_top.sv`: module `rv64im_core_sim_top`; instantiates `rv64im_core_reg` counters and `rv64im_core_top`; simulation top.
- `vsrc/ifu/rv64im_core_satcnt.sv`: module `rv64im_core_satcnt`; instantiated by `rv64im_core_ifu`.
- `vsrc/wb/rv64im_core_wb.sv`: module `rv64im_core_wb`; instantiated by `rv64im_core_wbu`.
- `vsrc/wb/rv64im_core_wbu.sv`: module `rv64im_core_wbu`; instantiates `rv64im_core_wb` and `rv64im_core_reg`; instantiated by `rv64im_core_core`.
- `vsrc/ifu/rv64im_core_ifu.sv`: module `rv64im_core_ifu`; instantiates `rv64im_core_satcnt`, `rv64im_core_ras`, and `rv64im_core_reg`; instantiated by `rv64im_core_core`.
- `vsrc/bus/rv64im_core_Nto1.sv`: module `rv64im_core_Nto1`; no active instantiation observed in `rv64im_core_top`.
- `vsrc/ifu/rv64im_core_ras.sv`: module `rv64im_core_ras`; instantiated by `rv64im_core_ifu`.
- `vsrc/bus/rv64im_core_clint.sv`: module `rv64im_core_clint`; instantiates `rv64im_core_reg`; instantiated by `rv64im_core_top`.
- `vsrc/bus/rv64im_core_2to1.sv`: module `rv64im_core_2to1`; instantiated by `rv64im_core_top`.
- `vsrc/idu/rv64im_core_regfile.sv`: module `rv64im_core_regfile`; instantiates `rv64im_core_reg`; instantiated by `rv64im_core_idu`.
- `vsrc/idu/rv64im_core_id.sv`: module `rv64im_core_id`; instantiated by `rv64im_core_idu`.
- `vsrc/idu/rv64im_core_idu.sv`: module `rv64im_core_idu`; instantiates `rv64im_core_reg`, `rv64im_core_if_id`, `rv64im_core_id`, and `rv64im_core_regfile`; instantiated by `rv64im_core_core`.
- `vsrc/idu/rv64im_core_if_id.sv`: module `rv64im_core_if_id`; instantiates `rv64im_core_reg`; instantiated by `rv64im_core_idu`.
- `vsrc/bus/rv64im_core_AtoB.sv`: module `rv64im_core_AtoB`; instantiated by `rv64im_core_top`.
- `vsrc/bus/rv64im_core_1toN.sv`: module `rv64im_core_1toN`; instantiated by `rv64im_core_top`.
- `vsrc/bus/rv64im_core_axi.sv`: module `rv64im_core_axi_rw`; instantiated by `rv64im_core_top`.
- `vsrc/core/rv64im_core_core.sv`: module `rv64im_core_core`; instantiates `rv64im_core_ifu`, `rv64im_core_idu`, `rv64im_core_exu`, `rv64im_core_lsu`, `rv64im_core_wbu`, and `rv64im_core_pipe_ctrl`; instantiated by `rv64im_core_top`.
- `vsrc/core/rv64im_core_pipe_ctrl.sv`: module `rv64im_core_pipe_ctrl`; instantiated by `rv64im_core_core`.
- `vsrc/mem/rv64im_core_lsu.sv`: module `rv64im_core_lsu`; instantiates `rv64im_core_ls` and `rv64im_core_reg`; instantiated by `rv64im_core_core`.
- `vsrc/mem/rv64im_core_ls.sv`: module `rv64im_core_ls`; instantiated by `rv64im_core_lsu`.

Simulation top: `rv64im_core_sim_top`.

Synthesis top: `rv64im_core_top`.

## C/C++ Dependency Audit

Verilator class identity:

- `csrc/sim_main.cpp` includes `Vtop.h` and `Vtop__Dpi.h`.
- `csrc/sim_main.cpp` declares global `Vtop* top`.
- `init_sim()` constructs `top = new Vtop`.
- `single_cycle()` drives `top->clk`, `top->eval()`, and optionally `top->trace(...)`.
- The executable path expected by Makefile is `./build/Vtop`.

Top object members used directly by C++:

- Clock/reset: `top->clk`, `top->rstn`
- DiffTest commit signals: `top->wb_sign`, `top->wb_pc`, `top->wb_inst`
- Interrupt/device signals: `top->wb_intr`, `top->intr_num`, `top->wb_device`

Verilator internal hierarchy:

- C/C++ source does not reference `rootp` or `__DOT__`.
- RTL simulation top `rv64im_core_sim_top` does reference internal hierarchy under `u_rv64im_core_top.u_rv64im_core_core...` for writeback, CSR, branch, register file, LSU, and device inference probes.

DPI functions:

- Imported by RTL and implemented in `csrc/sim_main.cpp`: `set_ebreak`, `set_gpr_ptr`, `mem_read`, `mem_write`.
- `set_gpr_ptr` exposes a 33-entry register array where entry 32 is PC.
- `mem_read` reads host memory or RTC addresses.
- `mem_write` writes host memory and handles serial MMIO at `0xa00003f8`.

DiffTest:

- Legacy Makefile default reference model: `/home/icer/ysyx-workbench/nemu/build/riscv64-nemu-interpreter-so`.
- Verified baseline reference model: `/home/icer/ysyx-workbench/nemu/build/riscv64-nemu-ref-patched.so`, SHA256 `202f091d5721e0b567be3246c7bd9f8f234c34f685bbc8b01af003f5493ce0dc`.
- These two NEMU reference paths must not be treated as equivalent; Phase 1 should make the verified path explicit through machine-local configuration.
- `csrc/difftest.cpp` resolves `difftest_memcpy`, `difftest_regcpy`, `difftest_exec`, `difftest_raise_intr`, and `difftest_init` with `dlsym`.
- `exec_once()` commits one NEMU step when `CONFIG_DIFFTEST` and `wb_num != 0`.
- `top->wb_intr` triggers `ref_difftest_raise_intr(top->intr_num)` after the DUT commits the pre-interrupt instruction.
- `top->wb_device` triggers `difftest_skip_ref()`.

Logging and waveform paths:

- `CONFIG_WAVE` controls VCD dumping to root-relative `wave.vcd`.
- `wave` target opens `./wave.vcd` with `gtkwave`.
- `--log/-l` opens a user-provided log file in `init.cpp`; default logging is stdout.

## Identifier Search Summary

Active project identifiers to rename in later phases:

- RTL prefix and module/file names containing `zrv`.
- Legacy simulation top `rv64im_core_sim_top` to target `rv64im_core_sim_top`.
- Legacy synthesis top `rv64im_core_top` to target `rv64im_core_top`.
- Legacy filelist `zrv.f`.
- Legacy defines prefix `RV64IM_CORE_*`.

External platform/environment names to preserve:

- `ysyx-workbench`
- `ysyxSoC` when it appears as external platform context.
- NEMU, Abstract Machine, am-kernels, and other external dependency names.
- Parent ysyx tracer metadata in historical context.

Student or historical identifiers observed:

- `ysyx_22040735` appears in the parent Makefile and Git history commit messages.
- `22040735` appears as part of `ysyx_22040735`.
- No other active eight-digit student-like identifier was confirmed in tracked project source during Phase 0.

Historical records:

- `docs/history/*` intentionally records imported source hashes, baseline validation, source location, and the `mtimecmp` reset fix.
- Historical references to `zrv` and protected external paths should be preserved as provenance.

Build generated records:

- `build/` contains generated Verilator files and objects.
- `out/baseline/` contains baseline compile/hash artifacts.

## Backup File Reference Check

- `csrc/include/config.h.bak`: not referenced by Makefile source discovery, `zrv.f`, C/C++ includes, or RTL includes. It appears in `docs/history/IMPORTED_SOURCE.sha256`, `AGENTS.md`, and its own path only.
- `vsrc/exu/zrv_booth_mul.sv.before_split_var_20260802`: not referenced by Makefile source discovery, `zrv.f`, or source includes. Current `VSRCS=$(shell find ./vsrc -name "*.*v")` requires filenames ending in `v`, so this backup file is not selected. It defines duplicate legacy module `zrv_booth_mul`, so it must remain excluded if source discovery changes. It appears in `docs/history/IMPORTED_SOURCE.sha256`, `AGENTS.md`, and its own path.

## Directory Migration Impact

Proposed moves and expected consumers:

- `vsrc -> rtl/vsrc`: requires updating Verilator include path, RTL `include` resolution, filelists, docs, and any script using `./vsrc`.
- `csrc -> sim/csrc`: requires updating C/C++ source discovery, include paths, build object paths, and documentation.
- `csrc/include -> sim/csrc/include` or `sim/include`: choose one include root and update `CFLAGS`; `sim/csrc/include` is lowest risk because it preserves C source locality.
- `zrv.f -> rtl/filelists/`: requires splitting into simulation, synthesis, and lint scopes; current Makefile must later stop relying on `find`.

## Filelist Boundary Design

`rtl/filelists/sim.f` should contain:

- Phase 3 simulation top `rv64im_core_sim_top`.
- RTL required by `rv64im_core_top` using legacy `zrv` file and module names.
- Current behavioral RAM required for simulation, including `S011HD1P_X32Y2D128_BW.sv`.
- No C/C++ files.

`rtl/filelists/synth.f` should contain:

- Phase 3 synthesis top `rv64im_core_top`.
- Core, bus, cache, CLINT, IFU/IDU/EXU/MEM/WB, utility modules, and shared defines using legacy `zrv` file and module names.
- Excludes `rv64im_core_sim_top`, DPI-only content, C/C++ files, Verilator-generated files, and testbench logic.
- Because `rv64im_core_ram` instantiates `S011HD1P_X32Y2D128_BW`, `synth.f` cannot simply delete the RAM module and claim synthesis closure. Until an approved SRAM macro model, black-box model, generic synthesizable wrapper, or inferred RAM implementation is selected, `synth.f` must be marked draft or not guaranteed to fully elaborate.

`rtl/filelists/lint.f` should contain:

- The RTL lint scope used to keep active RTL clean.
- Likely includes synthesis RTL plus optionally simulation top in a separately documented mode.
- Must document intentional differences from `sim.f` and `synth.f`, especially DPI and RAM treatment.

Future names:

- Phase 5 naming cleanup may replace `rv64im_core_sim_top` with `rv64im_core_sim_top`.
- Phase 5 naming cleanup may replace `rv64im_core_top` with `rv64im_core_top`.
- Phase 3 filelists must not use the future names as current paths or module names.

## Simulation and Synthesis Boundary Notes

- `rv64im_core_sim_top` is simulation-only because it imports DPI functions, exposes DiffTest commit/device/interrupt signals, performs direct host memory DPI calls, and uses deep internal hierarchy references for verification observability.
- `rv64im_core_top` has an AXI-style external interface and no DPI imports in the audited source. It is the intended synthesis boundary.
- DPI boundary is in `rv64im_core_sim_top` plus `csrc/sim_main.cpp`; it should remain outside synthesis filelists.
- `S011HD1P_X32Y2D128_BW.sv` is a behavioral SRAM-like model used under `rv64im_core_ram`; synthesis handling is unresolved.

## Source-Audit Architecture Observations

- These are source audit observations only. They are not post-refactor regression PASS claims.
- ISA decode observed includes RV64 base integer operations, W-form operations, loads/stores, branch/jump, LUI/AUIPC, CSR, fence/fence.i, ecall, ebreak, and mret in `rv64im_core_id`.
- M extension decode observed includes `mul`, `mulh`, `mulhsu`, `mulhu`, `div`, `divu`, `rem`, and `remu`, including W-form support through `md_sext_w`.
- CSR/privilege support observed in source: `mstatus`, `mtvec`, `mepc`, `mcause`, `mtval`, `mie`, `mip`, `ecall`, `mret`, machine timer/software/external interrupt cause values.
- Pipeline modules observed: IFU, IDU, EXU, LSU/MEM, WBU, plus `rv64im_core_pipe_ctrl`.
- Multiplication uses `rv64im_core_booth_mul` and compressor helpers.
- Division uses iterative `rv64im_core_div` when `MULDIV_VERILOG` is defined.
- Branch prediction uses `PRED_1`, `SAT_CNT`, and `RAS` in `rv64im_core_defines.sv`; implementation modules are `rv64im_core_satcnt` and `rv64im_core_ras`.
- I/D Cache: `rv64im_core_top` instantiates `rv64im_core_dcache` twice; D-cache uses `CACHE_SIZE=8192`, I-cache uses `CACHE_SIZE=4096`, both use `LINE_SIZE=256`, `RW_DATA_WIDTH=64`, `RW_ADDR_WIDTH=32`.
- CLINT support: `rv64im_core_clint` implements `msip`, `mtimecmp`, and `mtime` at `0x20000000`, `0x20004000`, and `0x20003ff8`; `mtimecmp` reset is `64'hffff_ffff_ffff_ffff`.
- MMIO: C model handles RTC reads at `0xa0000048` and `0xa0000040`, serial write at `0xa00003f8`; config lists additional MMIO constants.
- Bus interface: `rv64im_core_top` exposes AXI-like AW/W/B/AR/R channels with 32-bit address, 64-bit data, 4-bit ID, 8-bit strobe, and 1-bit user defaults.
- Address/data widths: architectural data width is `64`; instruction width is `32`; top bus address width is `32`; reset PC macro is `64'h000000007FFFFFFC`.
- Privilege level breadth beyond observed machine-mode CSRs: TBD.
- Atomic, compressed, floating-point, vector, and supervisor/user-mode support: TBD from current audit; not claimed.
