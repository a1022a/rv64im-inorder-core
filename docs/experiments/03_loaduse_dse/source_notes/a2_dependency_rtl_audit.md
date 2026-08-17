# A2 Dependency RTL Audit

The old `dependency` category is not generic RAW accounting. Its source is
`rv64im_core_regfile.o_rf_id_flush_ex`: either raw ID instruction field
`rs1` or `rs2` equals the EX destination, EX write-enable is asserted, and
`i_rf_exu_load` is asserted. The condition becomes `core.idu_pipe_stall`.

## Stage and forwarding semantics

- Detection and the consumer are in ID. The producer is in EX.
- Both encoded source fields are compared without operand-use qualification.
- The equation does not exclude destination x0. Unused fields and x0 can
  therefore create false raw interlocks.
- Ordinary ALU, branch/link, CSR, and completed DIV/REM results use EX-to-ID
  forwarding because `i_rf_exu_load` is false for them.
- MEM and WB forwarding are also present. Loads and multiplies deliberately do
  not use EX forwarding.
- `rv64im_core_alu.o_alu_idu_load` is the OR of architectural load and multiply
  classification. The signal name is therefore narrower than its real meaning.
- DIV/REM uses `div_op && !div_ack` as the separate global EX stall and does not
  enter this dependency umbrella. CSR uses EX forwarding.

## Pipeline and memory timing

`rv64im_core_pipe_ctrl` stalls IF and ID and flushes the EX pipeline register
for an ID dependency when memory is not stalled. This inserts one bubble. A
memory stall freezes all five stages and has higher exclusive-attribution
priority, so an asserted dependency condition during memory wait is charged to
D-cache/memory rather than dependency.

The load address advances to LSU/MEM after the dependency sample. The LSU
returns the load result through MEM-to-ID forwarding. The synchronous cache RAM
does not provide the load result on the EX forwarding port during the dependent
ID cycle. A hit therefore still needs the ID bubble; a miss also incurs later
memory-stall cycles. Directed and workload profiles show every exclusively
attributed dependency episode is one cycle, but the control equation permits a
condition to remain asserted while a higher-priority global stall freezes the
pipeline.

## Meaning of the old counts

The old 190, 224, 127008, and 516128 values count cycles selected by this
priority: D-cache/memory, divider, branch recovery, `idu_pipe_stall`, I-cache,
other. They are neither generic RAW cycles nor automatically load-use cycles.
Phase 8R proves FIB's 224 are multiply dependencies, while bubble and both GOL
counts are true load-use dependencies.
