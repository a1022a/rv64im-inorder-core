# A2 Performance-Modeling Baseline

## Authoritative baseline

- DEV repository: `${LOCAL_HOME}/ysyx-workbench/rv64im-inorder-core`
- DEV branch: `feature/a2-sram64x64`
- Authoritative A2 commit: `df956d23cc420b761104f359792cfbd5bb5e4747`
- A2 tree SHA: `8e18953b162c90967c2e3d6453f6ec785bbe91a4`
- DEV worktree was clean at the time of this freeze.

The A2 cache configuration is unchanged and verified from the RTL:

- I-cache: 8192 bytes (8 KiB)
- D-cache: 8192 bytes (8 KiB)
- Associativity: 4 ways
- Cache line: 256 bits (32 bytes)
- Sets: 64 per cache (`8192 / (32 * 4)`)

`rtl/vsrc/cache/rv64im_core_ram.sv` instantiates four
`rv64im_core_sram64x64` banks, and both cache instances in
`rtl/vsrc/rv64im_core_top.sv` use the A2 configuration. The SRAM abstraction is
therefore integrated; no cache or SRAM architecture change is part of this
baseline freeze.

## Modeling checkout

- Modeling branch: `modeling/a2-performance-v1`
- Modeling worktree: `${LOCAL_HOME}/ysyx-workbench/rv64im-inorder-core-modeling-a2`
- Modeling base commit: `df956d23cc420b761104f359792cfbd5bb5e4747`
- Modeling tree SHA: `8e18953b162c90967c2e3d6453f6ec785bbe91a4`
- The modeling worktree was clean after creation and before this document was added.

The modeling branch is based directly on the authoritative DEV A2 commit. No
development, instrumentation, model, counter, or DSE work is included here.

## Publication audit

The following paths were inspected read-only:

- Repository: `${LOCAL_HOME}/rv64im-publication/rv64im-inorder-core`
  - branch: `feature/a2-sram64x64`
  - HEAD: `febcefeebb816bc66ce44feec31ff1d86c246fd5`
  - tree SHA: `8e18953b162c90967c2e3d6453f6ec785bbe91a4`
  - status: clean; tracks `origin/feature/a2-sram64x64`
  - history is a separate publication history; it has no merge-base with DEV
    commit `df956d23...`.
  - its tree is identical to the DEV A2 tree (the two-commit comparison is empty).
- Legacy modeling worktree: `${LOCAL_HOME}/rv64im-publication/rv64im-inorder-core-modeling`
  - branch: `modeling/performance-v1`
  - HEAD: `7d356526f535e12823338b9a6ea6666f4579c120`
  - tree SHA: `8b77149fcce002e1f6d50da2912e7d6ff6384a91`
  - status: clean
  - no commits are unique to this branch relative to its publication baseline;
    it points at the same commit as `main`.
  - tracked modeling-related content is limited to `models/README.md`; no
    performance model, counters, traces, DSE, or gem5 work was found.

The publication repository and legacy modeling worktree remain archived and
were not modified, rebased, merged, deleted, or reused.

## TBD items

- Availability and exact revisions of external `am-kernels` and NEMU paths for
  later baseline-validation runs: `TBD` until required by a validation gate.
- The mechanism for a controlled region of interest and the retirement event
  contract are intentionally deferred to Phase 1.
- No performance metrics, counters, traces, model implementation, or DSE has
  been started.
