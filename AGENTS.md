# RV64IM In-Order Core Engineering Rules

## Project scope

This repository is the formal engineering workspace for:

- Project: rv64im-inorder-core
- Repository root:
  /home/icer/ysyx-workbench/rv64im-inorder-core
- Current branch:
  refactor/engineering-v1
- Functional baseline commit:
  59bcac3
- Functional baseline tag:
  v0.1.0-functional-baseline

Only this repository is writable.

## Protected external locations

Never modify, rename, delete, move, overwrite, chmod, commit, or
generate files in:

- /home/icer/zrv_milestones
- /home/icer/ysyx-workbench/npc_zrv_v1_2_cleanup_try1
- /home/icer/ysyx-workbench/npc_zrv_v1_2_try1
- /home/icer/ysyx-workbench/nemu
- /home/icer/ysyx-workbench/abstract-machine
- /home/icer/ysyx-workbench/am-kernels
- /home/icer/rtl_compare_ab_20260802_1740

External projects may be inspected read-only when required to understand
build or test dependencies.

## Verified baseline

Before the engineering refactor:

- Verilator build: PASS
- build/Vtop SHA256:
  16b2f3b7d013e9eeb6fe38c292b9ee2132c91a5decb6465a420a5284b08538cf
- NEMU reference SHA256:
  202f091d5721e0b567be3246c7bd9f8f234c34f685bbc8b01af003f5493ce0dc
- dummy + DiffTest: PASS
- dummy exit status: 0
- good trap: 1
- fatal marker: 0

Historical full regression before this refactor:

- CPU tests: 33/33 PASS
- klib tests: 33/33 PASS
- dedicated klib unit tests: 8/8 PASS
- MicroBench: PASS
- AM help/hello: PASS
- AM RTC: PASS
- timer128 interrupt and mret: PASS
- DiffTest fatal markers: 0

Do not claim that a post-refactor result passes unless the corresponding
command has actually been run and its exit status and logs are retained.

## Current technical identity

Current legacy simulation top:

- zrv_soc

Current legacy synthesis top:

- zrv_top

Current Verilator output prefix:

- Vtop

Target naming:

- Project: rv64im-inorder-core
- RTL prefix: rv64im_core_
- Simulation top: rv64im_core_sim_top
- Synthesis top: rv64im_core_top

Keep the generated Verilator executable named Vtop when practical.

## Current project stage

Allowed work:

- repository structure engineering
- build-system engineering
- regression infrastructure
- naming cleanup
- documentation
- release packaging
- synthesis handoff skeleton

Not started and forbidden during this refactor:

- performance counter implementation
- performance optimization
- trace-driven modeling
- cache or branch-predictor modeling
- gem5 modeling
- design-space exploration
- functional RTL redesign
- formal synthesis execution
- STA
- LEC
- PPA evaluation

The models/ and synth/ directories may contain only accurate placeholder
documentation and future interfaces at this stage.

## Destructive operations

Never execute:

- rm -rf
- git reset --hard
- git clean -fd
- git clean -fdx
- git push
- git push --force
- git rebase
- git commit --amend
- history rewriting
- broad blind sed replacement
- deletion of untracked files without explicit approval

Never modify Git remotes.

Before large file moves or renames:

1. Show the exact source-to-destination mapping.
2. Confirm that destination paths do not already exist.
3. Use git mv for tracked files.
4. State the rollback commit.
5. Run the required test gate afterward.

## Behavior-preserving requirement

Engineering changes must not intentionally alter:

- ISA behavior
- pipeline behavior
- CSR semantics
- exception behavior
- interrupt behavior
- reset behavior
- memory map
- cache behavior
- CLINT behavior
- AXI behavior
- RAM semantics
- DiffTest behavior
- architectural performance behavior

Functional fixes must be separate, explicitly approved tasks and must
not be mixed with directory, build-system, or naming changes.

## Known risks

Inspect and document these risks before making changes:

1. The legacy Makefile invokes Git against the parent directory.
2. The current local history contains legacy commits before baseline
   commit 59bcac3. Do not push this history to GitHub.
3. zrv.f may combine simulation and synthesis sources.
4. zrv_soc is simulation-only.
5. zrv_top is the intended synthesis top.
6. S011HD1P_X32Y2D128_BW.sv is a behavioral RAM model.
7. The synthesis treatment of RAM is not yet decided.
8. C++ may depend on Verilator class names, DPI functions, or internal
   RTL hierarchy.
9. DiffTest commit, interrupt, and device-event inference is fragile.
10. The simplified AXI implementation is not a fully general,
    high-concurrency AXI4 implementation.
11. mtimecmp reset to 64'hffff_ffff_ffff_ffff is an intentional fix and
    must be preserved.
12. ysyx-workbench, NEMU, Abstract Machine, am-kernels, and ysyxSoC are
    external environment or platform names and must not be blindly
    renamed.
13. Original copyright, license, and source attribution must remain.
14. Legacy backup files currently exist:
    - csrc/include/config.h.bak
    - vsrc/exu/zrv_booth_mul.sv.before_split_var_20260802
    Confirm they are unused before proposing their removal.

## Target repository layout

The intended final structure is:

- rtl/vsrc
- rtl/include
- rtl/filelists/sim.f
- rtl/filelists/synth.f
- rtl/filelists/lint.f
- sim/csrc
- config/default.mk
- config/local.mk.example
- scripts
- scripts/lib
- tests/manifests
- tests/custom
- docs
- models
- synth
- third_party
- out

out/ must remain ignored by Git.

## File-list boundaries

sim.f may contain:

- synthesizable RTL
- simulation top
- required simulation wrappers
- required behavioral RAM models

sim.f must not contain C or C++ files.

synth.f must contain only intended synthesis RTL and must exclude:

- simulation top
- DPI-only logic
- testbench logic
- C and C++ files
- Verilator-generated files
- simulation-only models unless explicitly approved

Do not silently choose a synthesis policy for the RAM model. Record it
as unresolved in docs/known_issues.md and synth/README.md.

lint.f must define the intended RTL lint scope. Differences among sim.f,
synth.f, and lint.f must be documented.

## Target build interface

The final stable commands are:

- make doctor
- make build
- make run TEST=dummy
- make smoke
- make regress
- make clean
- make release

All generated files must go under out/ where practical.

Machine-specific paths must not be scattered through public Makefiles
and scripts.

Portable defaults belong in:

- config/default.mk

Machine-local overrides belong in ignored:

- config/local.mk

## Refactor phases

Phase 0:
- read-only audit and planning
- only engineering documents may change

Phase 1:
- make the existing baseline reproducible
- no directory or RTL naming changes

Phase 2:
- move source directories only
- do not rename RTL identifiers

Phase 3:
- create sim.f, synth.f, and lint.f

Phase 4:
- implement doctor, build, run, smoke, and regress interfaces
- retain legacy RTL names

Phase 5:
- rename legacy RTL identifiers in subsystem-sized batches

Phase 6:
- run full regression and complete documentation

Phase 7:
- implement deterministic release packaging

## Execution modes

Default interactive mode:

- Stop after each phase for user review and approval.
- Do not automatically continue into the next phase.

Explicit Goal execution mode:

- Enabled only when the user explicitly sets a Goal and requests
  execution of an approved EXECUTION_PLAN.md.
- After all validation gates for the current phase pass, a local
  checkpoint commit may be created and execution may automatically
  continue to the next phase.
- Normal phase-boundary user confirmation is not required in this mode.

Goal execution mode must stop immediately if any of the following occur:

- build, dummy, or DiffTest failure
- regression results below baseline
- need to change RTL functional behavior
- need to modify files outside this repository
- need to decide the formal RAM synthesis strategy
- unplanned C++ hierarchy dependency discovered
- unplanned file modified
- need to delete history, source, or license content
- need to modify Git remote, push, or rewrite history
- unable to prove functional equivalence

## Required reporting

Before each phase report:

- objective
- files expected to change
- commands to be run
- test gate
- rollback point

After each phase report:

- files changed
- commands run
- exit codes
- test results
- git status --short
- git diff --stat
- remaining risks

In default interactive mode, stop after each phase for user review.

## Minimum test gates

After structural changes:

- Verilator build PASS
- dummy + DiffTest PASS
- no fatal DiffTest marker

After major build-system changes:

- build PASS
- smoke suite PASS

Final acceptance:

- CPU tests: 33/33
- klib tests: 33/33
- dedicated klib unit tests: 8/8
- MicroBench: PASS
- AM help/hello: PASS
- AM RTC: PASS
- timer128: PASS
- no DiffTest mismatch
- no bad trap
- no abort
- no assertion failure
- no non-convergence marker
