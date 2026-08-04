`define RV64IM_CORE_PC_RESET_ADDR       64'h000000007FFFFFFC

`define RV64IM_CORE_DATA_WIDTH    64
`define RV64IM_CORE_INST_WIDTH    32

`define RV64IM_CORE_INST_NOP     32'h00000013   //addi $0 0
`define RV64IM_CORE_INST_ECALL   32'h00000073
`define RV64IM_CORE_INST_EBREAK  32'h00100073

`define RV64IM_CORE_ALU_INFO         14 
`define RV64IM_CORE_MEM_INFO         12 
`define RV64IM_CORE_BJP_INFO         8 
`define RV64IM_CORE_MULDIV_INFO    9 
`define RV64IM_CORE_SYS_INFO       5
`define RV64IM_CORE_CSR_INFO       6

`define RV64IM_CORE_TYPE_INFO      6 
`define RV64IM_CORE_OP_INFO        `RV64IM_CORE_ALU_INFO

`define PRED_1

`ifdef PRED_0
    `define SP
`endif
`ifdef PRED_1
    `define SAT_CNT
    `define RAS
`endif 

`define TIME_OPT

`define MULDIV_VERILOG
