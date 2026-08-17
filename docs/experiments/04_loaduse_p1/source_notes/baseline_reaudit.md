# Load-Use P1 Baseline Re-Audit

Baseline commit `e9b27cd17077b7917c6612dae5403e1d1d47d1b6` detects a load-use
hazard in `rv64im_core_regfile` by comparing the EX destination against the ID
source fields. `rv64im_core_pipe_ctrl` stalls IF/ID and flushes the ID/EX
register, creating one bubble.

The producer load request is accepted by `rv64im_core_dcache` when `req_vld`
is true. In the same cycle, `req_hit` combines the accepted request with the
tag/valid comparison. A hit launches the selected synchronous SRAM bank. On
the following cycle, `way_hit_ff` selects `ram_rdata`, `vld_c1` asserts the
response, and `rv64im_core_ls` performs byte/half/word/doubleword selection and
sign extension. The formatted value already feeds the MEM-to-ID forwarding
path through `o_ls_idu_data`.

P1 reuses `req_hit` as the only early hit qualification. A true immediate RAW
consumer may enter EX only when that accepted D-cache request hit. In the next
cycle, the formatted LSU response overrides the matching EX operand. A miss
does not qualify, so the baseline bubble and memory-stall behavior remain.

No new synthesizable register is required. Flushes clear the existing ID/EX
instruction register, and downstream stalls preserve both the existing
instruction state and the LSU response holding behavior.
