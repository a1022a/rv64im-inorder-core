# Cache performance models

C0/C1 tools collect qualified cache counters. C2 exports accepted D-cache
accesses from reset, including PRE_ROI warmup, replays the RTL four-way
tree-PLRU policy, and sweeps 4, 8, 16, and 32 KiB at fixed four-way associativity
and 32-byte lines. It does not implement a cache RTL variant.

`replay_dcache.py` compares the 8 KiB replay against recorded RTL hit, miss, and
dirty-eviction outcomes. Those fields are calibration oracles only; address and
LOAD/STORE operation drive the software model. `analyze_dcache_capacity.py`
uses measured C1 stall-per-miss as a sensitivity estimate and enforces the
perfect-D$ upper bound. GOL128 demonstrates capacity sensitivity, while the
main GOL256 workload remains at 4080 misses across the sweep. Therefore
`CACHE_P1_JUSTIFIED=NO` and no cache RTL change was made.

Raw traces and generated outputs belong in ignored local output directories.
