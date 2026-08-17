# A2 Cache Counter Qualification

`bash scripts/run_perf_roi_retire.sh` passed with DiffTest and exact writeback
PC checking. The extended simulation-only directed ROI covers I$ hit and cold
miss/refill, D$ load hit, load miss/refill, store hit, store miss, and a forced
same-set dirty eviction/writeback.

| Invariant / event | Observed |
|---|---:|
| I access = hit + miss | 39 = 34 + 5 |
| D access = load + store | 8 = 3 + 5 |
| D access = hit + miss | 8 = 3 + 5 |
| load access = hit + miss | 3 = 2 + 1 |
| store access = hit + miss | 5 = 1 + 4 |
| D miss allocation / refill completion | 5 / 5 |
| dirty eviction / writeback completion | 1 / 1 |

The machine-readable result is
`out/perf_roi_retire/cache_counter_directed.json`; its
`counter_invariants_pass` is true and simulator exit status is zero.
