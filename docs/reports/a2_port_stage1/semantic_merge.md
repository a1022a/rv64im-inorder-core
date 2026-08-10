# A2 Semantic Merge

The merge is semantic, not whole-file replacement; Phase 5--9 development fixes remain intact.

- Both cache defaults are 8192 bytes; line size remains 256 bits and ways remain four.
- `ARRY_DEPTH=8192/32/4=64`; `INDEX_SIZE=$clog2(64)=6`.
- Tags, valid/dirty, PLRU, refill, writeback, and miss-address reconstruction use parameterized index slices; no fixed 32-set assumption remains.
- `rv64im_core_ram` retains four banks, each using synchronous `rv64im_core_sram64x64`.
- Generic mode is behavioral 64x64 RAM. `ASIC_SRAM` exposes only macro `TEM5N28HPCPLVTA64X64M4SWSO`; no vendor model, `.lib`, or `.db` is added.
