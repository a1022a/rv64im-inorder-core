`include "rv64im_core_defines.sv"

module rv64im_core_id_alu (
    input  wire [`RV64IM_CORE_INST_WIDTH-1:0] i_id_alu_inst,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_id_alu_pc,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_id_alu_rs1_data,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_id_alu_rs2_data,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_id_alu_imm_data,
    input  wire [4:0] i_id_alu_rd_index,
    input  wire [`RV64IM_CORE_TYPE_INFO-1:0] i_id_alu_type_info,
    input  wire [`RV64IM_CORE_OP_INFO-1:0] i_id_alu_op_info,

    input wire i_id_alu_flush,              // 流水线冲刷标志
    input wire i_id_alu_stall,              // 流水线等待标志

    output wire [`RV64IM_CORE_INST_WIDTH-1:0] o_id_alu_inst,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_id_alu_pc,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_id_alu_rs1_data,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_id_alu_rs2_data,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_id_alu_imm_data,
    output wire [4:0] o_id_alu_rd_index,

    output wire [`RV64IM_CORE_TYPE_INFO-1:0] o_id_alu_type_info,
    output wire [`RV64IM_CORE_OP_INFO-1:0] o_id_alu_op_info,

    input  wire clk,
    input  wire rstn
);
    wire reset = !rstn | i_id_alu_flush;
    rv64im_core_reg #(`RV64IM_CORE_INST_WIDTH,`RV64IM_CORE_INST_NOP) reg_if_id_alu_inst(clk,reset,i_id_alu_inst,o_id_alu_inst,!i_id_alu_stall);
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_id_alu_pc(clk,reset,i_id_alu_pc,o_id_alu_pc,!i_id_alu_stall);

    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_id_alu_rs1_data(clk,reset,i_id_alu_rs1_data,o_id_alu_rs1_data,!i_id_alu_stall);
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_id_alu_rs2_data(clk,reset,i_id_alu_rs2_data,o_id_alu_rs2_data,!i_id_alu_stall);
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_id_alu_imm_data(clk,reset,i_id_alu_imm_data,o_id_alu_imm_data,!i_id_alu_stall);
    rv64im_core_reg #(5,0) reg_id_alu_rd_index(clk,reset,i_id_alu_rd_index,o_id_alu_rd_index,!i_id_alu_stall);

    rv64im_core_reg #(`RV64IM_CORE_TYPE_INFO,0) reg_alu_type_info(clk,reset,i_id_alu_type_info,o_id_alu_type_info,!i_id_alu_stall);
    rv64im_core_reg #(`RV64IM_CORE_OP_INFO,0) reg_alu_op_info(clk,reset,i_id_alu_op_info,o_id_alu_op_info,!i_id_alu_stall);
endmodule //rv64im_core_if_id