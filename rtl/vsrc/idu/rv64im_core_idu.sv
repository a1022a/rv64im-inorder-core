`include "rv64im_core_defines.sv"

module rv64im_core_idu (
    input  wire [`RV64IM_CORE_INST_WIDTH-1:0] i_idu_inst,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_idu_pc,
    input  wire i_idu_if_vld,
    input  wire i_idu_stall,
    input  wire i_idu_flush,

    input  wire i_idu_wb_stall,
    input  wire i_idu_rd_wen,
    input  wire [4:0] i_idu_rd_index,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_idu_rd_data,

    input  wire i_idu_exu_load,
    input  wire i_idu_exu_rd_wen,
    input  wire [4:0] i_idu_exu_rd_index,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_idu_exu_rd_data,
    input  wire i_idu_mem_rd_wen,
    input  wire [4:0] i_idu_mem_rd_index,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_idu_mem_rd_data,
    output wire o_idu_id_flush_ex,

    output wire [`RV64IM_CORE_INST_WIDTH-1:0] o_idu_inst,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_idu_pc,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_idu_rs1_data,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_idu_rs2_data,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_idu_imm_data,
//    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_idu_jalr_chk_data, //? tgt_addr = rs1 + imm12 
    output wire [4:0] o_idu_rd_index,

    output wire [`RV64IM_CORE_TYPE_INFO-1:0] o_idu_type_info,
    output wire [`RV64IM_CORE_OP_INFO-1:0] o_idu_op_info,
`ifdef SAT_CNT
    input  wire if_id_predict_pt,
    output wire id_bx_predict_pt,
`endif
    input  wire clk,
    input  wire rstn
);

`ifdef SAT_CNT
    wire wen = !(i_idu_stall);
    wire reset = !rstn | i_idu_flush;
    rv64im_core_reg #(1,0) reg_if_id_pc(clk,reset,if_id_predict_pt,id_bx_predict_pt,wen);
`endif

wire [`RV64IM_CORE_INST_WIDTH-1:0] idu_inst_ns = i_idu_if_vld ? i_idu_inst : `RV64IM_CORE_INST_NOP;
wire [`RV64IM_CORE_DATA_WIDTH-1:0] idu_pc_ns = i_idu_if_vld ? i_idu_pc : 64'd0;
wire [`RV64IM_CORE_INST_WIDTH-1:0] reg_id_inst;
wire [`RV64IM_CORE_DATA_WIDTH-1:0] reg_id_pc;

wire [4:0] id_rf_rs1_index;
wire [4:0] id_rf_rs2_index;


rv64im_core_if_id u_rv64im_core_if_id(
    .i_if_id_inst  (idu_inst_ns ),
    .i_if_id_pc    (idu_pc_ns   ),
    .i_if_id_flush (i_idu_flush ),
    .i_if_id_stall (i_idu_stall ),
    .o_if_id_inst  (reg_id_inst  ),
    .o_if_id_pc    (reg_id_pc    ),

    .clk           (clk           ),
    .rstn          (rstn          )
);

rv64im_core_id u_rv64im_core_id(
    .i_id_inst      (reg_id_inst      ),
    .i_id_pc        (reg_id_pc        ),
    .o_id_inst      (o_idu_inst      ),
    .o_id_pc        (o_idu_pc        ),
    .o_id_imm_data  (o_idu_imm_data  ),
    .o_id_rs1_index (id_rf_rs1_index ),
    .o_id_rs2_index (id_rf_rs2_index ),
    .o_id_rd_index  (o_idu_rd_index  ),
    .o_id_type_info (o_idu_type_info ),
    .o_id_op_info   (o_idu_op_info   )
);



rv64im_core_regfile u_rv64im_core_regfile(
    .i_rf_wb_stall  (i_idu_wb_stall  ),
    .i_rf_rd_data   (i_idu_rd_data   ),
    .i_rf_rd_index  (i_idu_rd_index  ),
    .i_rf_rd_wen    (i_idu_rd_wen     ),

    .i_rf_exu_load     (i_idu_exu_load     ),
    .i_rf_exu_rd_wen   (i_idu_exu_rd_wen   ),
    .i_rf_exu_rd_index (i_idu_exu_rd_index ),
    .i_rf_exu_rd_data  (i_idu_exu_rd_data  ),
    .i_rf_mem_rd_wen   (i_idu_mem_rd_wen   ),
    .i_rf_mem_rd_index (i_idu_mem_rd_index ),
    .i_rf_mem_rd_data  (i_idu_mem_rd_data  ),
    .o_rf_id_flush_ex  (o_idu_id_flush_ex  ),

    .i_rf_rs1_index (id_rf_rs1_index ),
    .i_rf_rs2_index (id_rf_rs2_index ),
    .o_rf_rs1_data  (o_idu_rs1_data  ),
    .o_rf_rs2_data  (o_idu_rs2_data  ),
    .clk            (clk            ),
    .rstn           (rstn           )
);

endmodule //idu

