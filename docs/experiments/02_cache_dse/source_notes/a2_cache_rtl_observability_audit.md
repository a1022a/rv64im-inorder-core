# A2 Cache RTL Observability Audit

## Frozen architecture

Both instances use `rv64im_core_dcache`: I$ and D$ are each 8192 bytes,
four-way, 32-byte-line, 64-set blocking write-allocate/write-back caches.
`PERFORMANCE_MODEL` exports existing combinational signals only. No cache
array, FSM, PLRU, AXI, SRAM, pipeline, or synthesized counter is changed.

## I-cache

- A new lookup is `req_vld = i_mem_req_vld & o_mem_req_rdy`; the IFU request
  may be held, but `o_mem_req_rdy = state_is_norm & ~stall_c1` prevents a
  held request from becoming repeated miss events while WBUS/RBUS is active.
- `req_hit` and `req_miss` are valid on that accepted NORM lookup edge.
  `req_miss` is the unique miss-allocation event.
- `rbus_en` starts refill and `rbus_done = bus_wram_vld & rcnt==3` completes
  the fourth 64-bit refill beat. `state_is_rbus` is refill occupancy.
- The most direct cache wait is WBUS/RBUS/`stall_c1`; I$ never writes, so WBUS
  is architecturally unreachable here. IFU response backpressure is
  `stall_c1 = o_mem_rsp_vld & ~i_mem_rsp_rdy`.
- IFU flushes can discard/reissue speculative fetches. Accesses therefore
  include wrong-path fetch activity and are not retirement counts.

## D-cache and LSU

- Address acceptance is the cache `req_vld`. The 1-to-N decode sends only
  addresses with high nibble `8` to D$; CLINT (`2`) and other MMIO/device
  paths bypass it and are excluded automatically.
- `i_mem_wen` distinguishes store from load on the accepted edge. The same
  NORM/WBUS/RBUS FSM services load and store misses.
- `req_hit`/`req_miss` are the decision events. `rbus_en`/`rbus_done` define
  refill start/completion. Store-miss data is merged into the refill beat.
- A dirty valid selected victim is `vic_dry = |(way_vic & way_dry & way_vld)`.
  `wbus_en = req_miss & vic_dry` is both dirty-eviction and writeback-start;
  `wbus_done = wover_one & wcnt==3` completes the fourth writeback beat.
- `state_is_rbus`, `state_is_wbus`, and their union plus `stall_c1` are miss,
  writeback, and total cache stall occupancy. Existing `mem_pipe_stall` is
  LSU/pipeline memory wait; it matched D$ total occupancy in calibrated ROIs.
- LSU may hold `o_ls_req_vld` while not ready. Cache acceptance, rather than
  request level, is therefore mandatory for transaction counting.

## SRAM and replacement timing

`rv64im_core_ram` selects one of four 64-bit banks and registers bank select;
`rv64im_core_sram64x64` performs synchronous read on the rising edge. PLRU is
updated on hit or refill completion. No replacement or RAM timing policy is
modified. The formal RAM synthesis policy remains outside C0+C1.
