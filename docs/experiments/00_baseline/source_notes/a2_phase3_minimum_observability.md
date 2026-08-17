# A2 Phase 3 Minimum Observability

Phase 3 adds simulation-only ports on `rv64im_core_sim_top` and an opt-in C++
raw collector. No synthesizable pipeline, cache, SRAM, AXI, CSR, or
architectural interface is changed. `rtl/filelists/synth.f` excludes the
simulation top, so these ports and the collector are absent from synthesis.

The active simulation configuration defines `SAT_CNT`, `RAS`, and
`MULDIV_VERILOG` in `rtl/vsrc/rv64im_core_defines.sv`; the top parameters are
8 KiB I-cache/D-cache, four ways, 32-byte lines, and 64 sets. Raw sampling
occurs after each existing `single_cycle()` rising-edge evaluation. Event
fields count sampled assertions; occupancy fields count one cycle per level.
Collection remains opt-in through `PERF_RAW_OUT` and does not alter DiffTest
ordering when disabled.

## Raw fields

- `branch_resolved_observation_count`: ALU `bjp_req`, resolved branch/JAL/JALR activity; not necessarily a redirect and not retirement.
- `branch_direction_error_count`: active SAT_CNT ALU `cond_err` resolution events.
- `jalr_target_error_count`: active RAS ALU `jalr_err` target-error events.
- `icache_miss_observation_count`: I-cache `req_miss`, defined as accepted request (`req_vld = i_mem_req_vld && o_mem_req_rdy`) and tag miss; not refill-state cycles and potentially speculative.
- `dcache_miss_observation_count`: D-cache `req_miss` with the same accepted-request definition; LSU retirement relation remains TBD.
- `icache_wait_cycles`: I-cache writeback/refill/response-backpressure level (`state_is_wbus || state_is_rbus || stall_c1`).
- `dcache_memory_wait_cycles`: core `mem_pipe_stall`/LSU memory wait occupancy.
- `load_use_stall_cycles`: IDU `idu_pipe_stall` load-use hazard occupancy.
- `divider_wait_cycles`: ALU `div_op && !div_ack`, the condition included in `o_alu_stall`.
- `flush_observation_count`: generic `|pipec_flush`; distinct from branch errors and may overlap causes.
- `flush_branch_count`, `flush_interrupt_count`, `flush_dependency_count`: raw cause candidates from ALU flush, interrupt-control flush, and IDU hazard flush respectively.

All raw indicators are independent and may overlap; they are not CPI
contributions. `measurement_scope` remains `full_run` and `roi_valid` remains
`false`, so startup, I/O, traps, and termination are included.

`wb_sign` remains the Phase 2 `PARTIAL_RETIREMENT_EVENT`. This phase does not
publish retired instructions, IPC/CPI, architectural load/store counts, or a
retire-valid signal. Directed Phase 4 testing remains required.

## Isolation and validation

The observer is instantiated only through simulation-top public ports and C++;
`synth.f` contains neither `rv64im_core_sim_top` nor simulation C/C++ files.
`make doctor` and `make build` pass with collection disabled. Determinism,
I-cache directed sanity, and full regression remain required before commit.
