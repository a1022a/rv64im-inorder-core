# A2 Cache C0+C1 Summary

C0 counter semantics and directed qualification pass. C1 profiles the four
authorized workloads without changing the 8 KiB, four-way, 32-byte-line cache
architecture. Normal build, dummy, smoke, and exact GOL non-perturbation pass.

The measured cache opportunity is limited: perfect-cache exclusive upper
bounds are approximately 1.0133x FIB, 1.0225x bubble-sort, 1.0303x GOL128, and
1.0299x GOL256. GOL D$ behavior is repeatable and measurable, but around 2.9%
of ROI cycles is not dominant. Cache P1 is not justified by C0+C1 alone;
capacity impact remains `NOT_DECIDED_UNTIL_C2`.

## Provenance and artifact roots

- `CACHE_MODEL_SOURCE_BASE_COMMIT=a82a98a01eb5cee84eb5497890f16366fb6814e2`
- `CACHE_MODEL_BRANCH=modeling/a2-cache-model-v1`
- `CACHE_MODEL_WORKTREE=${LOCAL_HOME}/ysyx-workbench/rv64im-inorder-core-modeling-cache-a2`
- Raw results: `${LOCAL_HOME}/rv64im-cache-model-scratch/results`
- Logs and exit codes: `${LOCAL_HOME}/rv64im-cache-model-scratch/logs` and
  `${LOCAL_HOME}/rv64im-cache-model-scratch/runs`

`CACHE_ARCHITECTURE_MODIFIED=NO`

`FUNCTIONAL_RTL_BEHAVIOR_MODIFIED=NO`

`SYNTHESIZABLE_DATAPATH_MODIFIED=NO`
