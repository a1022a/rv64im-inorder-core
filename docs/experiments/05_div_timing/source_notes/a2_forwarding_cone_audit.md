# A2 DIV Forwarding Cone Audit

## EX result selection

`DIV_RESULT_DIRECT_TO_FORWARDING=NO`.

For a DIV-family instruction, `rv64im_core_alu` first selects quotient versus
remainder with the masked-OR `muldiv_res` expression. It then applies W-form
sign extension in `muldiv_to_rd_data`. Finally, it selects among ordinary ALU,
branch/jump, MULDIV, and CSR data in the masked-OR `alu_rd_wdata` expression.
Only that general result is exposed as `o_alu_idu_data` and forwarded through
`rv64im_core_exu.o_exu_idu_data`.

There is no additional writeback-data mux on the same-cycle EX-to-ID route.
The core and IDU wires pass `o_exu_idu_data` directly to
`rv64im_core_regfile.i_rf_exu_rd_data`. The later MEM and WBU values are
independent alternatives in the ID forwarding selector.

## ID operand forwarding

Both source operands implement the same priority:

```text
x0 constant
  > EX result when index matches, EX writes, and EX is not a load/multiply
  > MEM result when index matches and MEM writes
  > WBU result when index matches and WBU writes
  > architectural register file
```

The RS1 conditions are `exu_hit_rs1`, `mem_hit_rs1`, and `wbu_hit_rs1`; RS2
uses the corresponding `rs2` conditions. X0 is checked first and always
returns zero. A DIV completion has no DIV-specific forwarding data path or
select. It uses ordinary `exu_hit_rs1`/`exu_hit_rs2`; `i_rf_exu_load` is false
for DIV, so the acknowledged result is eligible for same-cycle EX forwarding.

At the source level the forwarding data expression is one nested priority
ternary per operand. It represents a single ID operand-selection structure
with five alternatives, not five serial data muxes. Synthesis may implement
the priority with AOI/OAI or other cells, so this audit does not equate RTL
ternaries with mapped cell depth.

## Conceptual stage count

`CURRENT_DIV_TO_ID_FORWARDING_STAGE_COUNT=5_SELECTION_STAGES_PLUS_SIGN_CORRECTION`

The five conceptual data-selection stages after normal quotient correction
are:

1. fast-div versus normal quotient;
2. quotient versus remainder;
3. 64-bit versus W-form sign-extended result;
4. MULDIV versus the other general EX result classes;
5. EX versus MEM/WBU/register-file ID operand selection.

This count deliberately excludes pure module wiring and counts the ID priority
expression as one conceptual selection stage. It is not a mapped mux-depth
claim. The x0 override is part of stage 5.

## Result/forwarding cleanup candidate

- `CANDIDATE_ID=FEC1`
- `DESCRIPTION=Introduce a cycle-equivalent DIV-qualified data route into the existing EX forwarding selection so an acknowledged DIV can bypass some general ALU masked-OR result logic.`
- `RTL_FILES_AFFECTED=rtl/vsrc/exu/rv64im_core_alu.sv; rtl/vsrc/exu/rv64im_core_exu.sv; rtl/vsrc/core/rv64im_core_core.sv; rtl/vsrc/idu/rv64im_core_idu.sv; rtl/vsrc/idu/rv64im_core_regfile.sv`
- `LOGIC_CONE_AFFECTED=muldiv/general EX data selection through EX-to-ID forwarding input`
- `FUNCTIONALLY_EQUIVALENT_EXPECTED=YES`
- `CYCLE_BEHAVIOR_CHANGED=NO`
- `NEW_REGISTER_REQUIRED=NO`
- `ESTIMATED_SCOPE=MEDIUM`
- `TIMING_RATIONALE=Could remove one or more general result-selection terms from the DIV data route before ID selection.`
- `CORRECTNESS_RISK=MODERATE`

FEC1 is structurally possible but not preferred. It crosses five module
interfaces, duplicates result qualification at the forwarding boundary, and
leaves the measured post-`res_reg` two's-complement carry cone intact.

- `CANDIDATE_ID=FEC2`
- `DESCRIPTION=Rewrite the existing one-hot masked-OR DIV/REM and general EX result expressions as explicitly factored selects without adding a bypass interface.`
- `RTL_FILES_AFFECTED=rtl/vsrc/exu/rv64im_core_alu.sv`
- `LOGIC_CONE_AFFECTED=muldiv_res; muldiv_to_rd_data; alu_rd_wdata`
- `FUNCTIONALLY_EQUIVALENT_EXPECTED=YES`
- `CYCLE_BEHAVIOR_CHANGED=NO`
- `NEW_REGISTER_REQUIRED=NO`
- `ESTIMATED_SCOPE=TINY`
- `TIMING_RATIONALE=May expose mutually exclusive select structure more directly to synthesis, but the current decode is already one-hot-like and timing benefit is weakly supported.`
- `CORRECTNESS_RISK=LOW`

FEC2 is a low-risk source cleanup but not a strong direct remedy for the exact
launch-to-capture evidence. Fresh synthesis could map both forms identically.
