`include "rv64im_core_defines.sv"

module rv64im_core_if_id (
    input wire [`RV64IM_CORE_INST_WIDTH-1:0] i_if_id_inst,            // 指令内容
    input wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_if_id_pc,              // 指令地址

    input wire i_if_id_flush,              // 流水线冲刷标志
    input wire i_if_id_stall,              // 流水线等待标志

    output wire [`RV64IM_CORE_INST_WIDTH-1:0] o_if_id_inst,            // 指令内容
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_if_id_pc,              // 指令地址
    input wire clk,
    input wire rstn
);
    wire wen = !(i_if_id_stall);
    wire reset = !rstn | i_if_id_flush;
    rv64im_core_reg #(`RV64IM_CORE_INST_WIDTH,`RV64IM_CORE_INST_NOP) reg_if_id_inst(clk,reset,i_if_id_inst,o_if_id_inst,wen);
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_if_id_pc(clk,reset,i_if_id_pc,o_if_id_pc,wen);

endmodule //rv64im_core_if_id