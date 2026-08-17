# Engineering Refactor Plan

This plan starts after Phase 0. Do not automatically enter Phase 1.

## Phase 1: Makefile Safety and Existing-Layout Baseline

- Goal: eliminate legacy Makefile automatic Git commits and parent-directory Git side effects; establish a safe, repeatable baseline using the current `vsrc`, `csrc`, and `zrv.f` layout.
- File changes: `Makefile`, `config/default.mk`, `config/local.mk.example`, and minimal scripts/docs needed for safe baseline capture. Do not move directories, split filelists, or rename RTL in this phase.
- Risks: breaking legacy `make comp/run`; accidentally changing simulation behavior; using the wrong NEMU reference model; losing `Vtop` executable compatibility.
- Verification commands: `make doctor` if introduced, safe build command replacing legacy `make comp`, dummy DiffTest command using the explicitly configured verified baseline NEMU reference model, `git status --short`.
- PASS standard: build/run commands no longer create Git commits; baseline build and dummy DiffTest are reproduced from current layout with retained logs and exit statuses; no post-refactor PASS is claimed unless that command was run.
- Git rollback point: commit at the end of Phase 1 after approval and verified baseline reproduction.
- User approval required: yes, because Makefile behavior and reference-model configuration change.

## Phase 2: Directory Migration Only

- Goal: migrate `vsrc` and `csrc` into the target directory structure while preserving legacy RTL names and behavior.
- File changes: `git mv vsrc rtl/vsrc`, `git mv csrc sim/csrc`, update Makefile/include paths and minimal docs; keep module names, file names, `rv64im_core_sim_top`, `rv64im_core_top`, and `RV64IM_CORE_*` macros unchanged.
- Risks: broken include paths, generated files landing outside expected directories, stale path assumptions in C/C++ and docs.
- Verification commands: `make doctor`, safe build command, dummy DiffTest command using the explicitly configured verified NEMU reference, `git status --short`.
- PASS standard: build and dummy DiffTest reproduce Phase 1 behavior with retained logs; source content changes are limited to path/include/build references needed by migration.
- Git rollback point: commit before migration and commit after successful migration verification.
- User approval required: yes, because directory moves are large.

## Phase 3: Legacy-Name Filelist Split

- Goal: create explicit `sim.f`, `synth.f`, and `lint.f` while still using legacy names.
- File changes: create `rtl/filelists/sim.f`, `rtl/filelists/synth.f`, and `rtl/filelists/lint.f`; update build to consume `sim.f` if approved; `zrv.f` may be retained for compatibility or adjusted only as migration requires.
- Risks: source ordering mistakes; accidentally excluding required RAM definitions; accidentally including simulation-only DPI content in synthesis scope; backup file duplicate-module exposure.
- Verification commands: safe build using `rtl/filelists/sim.f` with top `rv64im_core_sim_top`, lint/filelist parse command for `rv64im_core_top` scope if available, `git diff --check`.
- PASS standard: `sim.f` builds the legacy `rv64im_core_sim_top` simulation top; `synth.f` documents the legacy `rv64im_core_top` synthesis scope and is marked draft/not fully elaboratable until RAM policy is approved; `lint.f` documents its exact scope.
- Git rollback point: commit after filelist split and verification.
- User approval required: yes, because build source selection changes.

## Phase 4: Stable Engineering Interfaces

- Goal: establish stable `doctor`, `build`, `run`, `smoke`, `regress`, and `clean` interfaces while keeping legacy RTL names.
- File changes: Makefile targets, scripts under `scripts/`, test manifests under `tests/` if needed, docs.
- Risks: command names implying broader validation than actually run; external AM/NEMU path variance; generated file placement.
- Verification commands: `make doctor`, `make build`, `make run TEST=dummy`, `make smoke`, selected `make clean` behavior check, `git status --short`.
- PASS standard: each stable command has documented inputs, outputs, exit status, and retained logs; no command creates Git commits; no post-refactor PASS is claimed without execution.
- Git rollback point: commit after stable interfaces pass smoke.
- User approval required: yes for full regression scope; yes before changing public command semantics.

## Phase 5: Subsystem Naming Cleanup

- Goal: rename project-internal `zrv`/`ZRV` identifiers and top names by subsystem after build and regression interfaces are stable.
- File changes: RTL filenames/modules/macros, filelists, C++ includes and top-port references as needed; only after this phase may `rv64im_core_sim_top` and `rv64im_core_top` replace `rv64im_core_sim_top` and `rv64im_core_top`.
- Risks: Verilator public API changes, DPI function names, internal hierarchy probes, DiffTest commit/device/interrupt signals, over-renaming external or historical identifiers.
- Verification commands: `make build`, `make smoke`, relevant regression subset, targeted searches for active legacy identifiers and preserved external/history names.
- PASS standard: each subsystem rename preserves Phase 4 behavior with retained logs; historical/provenance/external names remain intact.
- Git rollback point: commit before each subsystem rename batch and after each verified batch.
- User approval required: yes, because this is broad and high-risk.

## Phase 6: Full Regression and Documentation

- Goal: run and document the complete approved regression set and update engineering/user documentation.
- File changes: docs, regression manifests, log summaries, release notes draft if needed.
- Risks: false PASS claims, missing logs, drift from baseline test definitions, long runtime.
- Verification commands: `make regress` or the explicitly approved full regression command set; targeted smoke reruns after documentation or script changes.
- PASS standard: regression results include commands, exit statuses, log locations, failure markers, and scope; unsupported or unrun items are marked TBD or not run.
- Git rollback point: commit after complete regression and documentation review.
- User approval required: yes before running long/full regression.

## Phase 7: Deterministic Release Packaging

- Goal: produce deterministic release packaging from the cleaned repository state.
- File changes: release scripts, packaging manifests, release documentation, generated release artifacts under `out/` if approved.
- Risks: packaging generated files into source history, leaking machine-local paths, nondeterministic archives, publishing an unclean Git history.
- Verification commands: `make release` or `make release DRY_RUN=1`, archive manifest/hash checks, `git status --short`.
- PASS standard: release artifact content and hashes are reproducible; generated outputs remain under `out/`; clean GitHub history strategy is complete before publication.
- Git rollback point: release candidate commit/tag only after user approval.
- User approval required: yes for release creation and any GitHub publication.

## Recommended Order

1. Make the legacy Makefile safe and reproduce the current baseline in place.
2. Move only directories while preserving legacy names.
3. Split filelists using `rv64im_core_sim_top` and `rv64im_core_top`.
4. Add stable engineering commands while legacy names still work.
5. Rename `zrv`/`ZRV` by subsystem only after stable gates exist.
6. Run complete approved regression and finish documentation.
7. Package deterministic release artifacts after history and validation are clean.
