# A2 DIV-to-ID Path RTL Mapping

## Scope and provenance

This is a read-only mapping of the P1 source at commit
`4858651e70bd41fb9cc789a4b09a3f0de624d46a` and tree
`b289a9a430ffb387d268b43bd08cc08f84022102`. No timing result in this
document comes from a new synthesis or STA run.

The exact qualified P1 500 MHz PrimeTime trigger is:

- Startpoint: `u_rv64im_core_core/u_rv64im_core_exu/u_rv64im_core_alu/u_rv64im_core_div/res_reg_reg[0]/CP`
- Endpoint: `u_rv64im_core_core/u_rv64im_core_exu/u_rv64im_core_id_alu/reg_id_alu_rs1_data/dout_reg[63]/D`
- Setup WNS: `-0.001319 ns`
- Family: `DIV_RESULT_TO_ID_ALU_RS1_OPERAND_REGISTER`

The exact P1 run reports 41 setup violations, DC/PT correlation PASS, and
fast/min hold PASS with `+0.037408 ns` WNS. The direct load-use probe has
`+0.173345 ns` WNS and is not in the overall top 20, so this audit does not
alter Load-use P1.

## Source and destination

| Boundary | Module | Source object |
| --- | --- | --- |
| Launch | `rv64im_core_div` | `res_reg[0]`, a bit of the iterative unsigned quotient register |
| Capture | `rv64im_core_id_alu` | `reg_id_alu_rs1_data` input `i_id_alu_rs1_data`, captured at `dout_reg[63]/D` |

`res_reg` is declared in `rtl/vsrc/exu/rv64im_core_div.sv` and updated with
`{res_reg[62:0], ~add_sign}`. It is not a register containing the final signed
architectural DIV result.

## Actual RTL chain

The exact source-level data chain is:

```text
rv64im_core_div.res_reg
  -> div_res_sel = (op1_signed ^ op2_signed) ? (~res_reg + 1) : res_reg
  -> div_res = fast_div_r ? {64{~|dvld_cnt_r}} : div_res_sel
  -> rv64im_core_alu.muldiv_res
       = mask(div | divu, div_res) | mask(rem | remu, rem_res)
  -> muldiv_to_rd_data
       = md_sext_w ? sign_extend(muldiv_res[31:0]) : muldiv_res
  -> alu_rd_wdata
       = mask(alu_to_rd_we, alu_to_rd_data)
       | mask(bjp_to_rd_we, bjp_to_rd_data)
       | mask(muldiv_to_rd_we, muldiv_to_rd_data)
       | mask(csr_to_rd_we, csr_to_rd_data)
  -> rv64im_core_alu.o_alu_idu_data
  -> rv64im_core_exu.o_exu_idu_data
  -> rv64im_core_core.exu_idu_exu_rd_data
  -> rv64im_core_idu.i_idu_exu_rd_data
  -> rv64im_core_regfile.i_rf_exu_rd_data
  -> o_rf_rs1_data
       = rs1_is_x0 ? 0
       : exu_hit_rs1 ? i_rf_exu_rd_data
       : mem_hit_rs1 ? i_rf_mem_rd_data
       : wbu_hit_rs1 ? i_rf_rd_data
       : regs[i_rf_rs1_index]
  -> rv64im_core_idu.o_idu_rs1_data
  -> rv64im_core_exu.i_exu_rs1_data
  -> rv64im_core_id_alu.i_id_alu_rs1_data
  -> reg_id_alu_rs1_data.din
  -> reg_id_alu_rs1_data.dout_reg[63]/D
```

The named ports and core wires between the ALU and IDU are connectivity only;
they do not imply extra RTL selection stages. The data-producing expressions
are the quotient correction and special-case select in the divider, the
DIV/REM and W-form selections plus general result selection in the ALU, and
the EX/MEM/WBU/register-file priority expression in the register file.

## Evidence limits

The shared `rtl_path_correlation.rpt` independently maps the same source
chain. The shared `p1p35_delay_decomposition.rpt` shows a historical 1.35 ns
instance of this family with 46 combinational output arcs and 18 half-adder
cells. That historical report is useful structural evidence for a long carry
topology, but it is not the exact P1 2.0 ns netlist and is not used here to
claim exact P1 mapped depth or delay composition.

The exact P1 start bit `[0]` and endpoint bit `[63]`, combined with the RTL
expression `~res_reg + 1`, support the conclusion that quotient sign
correction is the primary long cone after the launch register. General result
selection and forwarding priority remain downstream contributors.
