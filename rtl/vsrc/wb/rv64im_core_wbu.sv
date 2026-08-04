`include "rv64im_core_defines.sv"

module rv64im_core_wbu (

    input  wire [4:0] i_wbu_rd_index,
    input  wire i_wbu_rd_wen,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_wbu_memtord_data,

    input wire i_wbu_flush,              // 流水线冲刷标志
    input wire i_wbu_stall,              // 流水线等待标志

    output wire [4:0] o_wbu_rd_index,
    output wire o_wbu_rd_wen,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_wbu_rd_data,
    input  wire clk,
    input  wire rstn
);
    wire reset = !rstn | i_wbu_flush;
    wire [4:0] reg_wb_rd_index;
    wire reg_wb_rd_wen;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] reg_wb_memtord_data;


rv64im_core_wb u_rv64im_core_wb(
    .i_wb_rd_index     (reg_wb_rd_index     ),
    .i_wb_rd_wen       (reg_wb_rd_wen       ),
    .i_wb_memtord_data (reg_wb_memtord_data ),
    .o_wb_rd_index     (o_wbu_rd_index     ),
    .o_wb_rd_wen       (o_wbu_rd_wen       ),
    .o_wb_rd_data      (o_wbu_rd_data      )
);

    rv64im_core_reg #(5,0)               reg_mem_wb_rd_index    (clk,reset,i_wbu_rd_index,reg_wb_rd_index,!i_wbu_stall);
    rv64im_core_reg #(1,0)               reg_mem_wb_rd_wen      (clk,reset,i_wbu_rd_wen,reg_wb_rd_wen,!i_wbu_stall);
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_mem_wb_memtord_data(clk,reset,i_wbu_memtord_data,reg_wb_memtord_data,!i_wbu_stall);  


endmodule //rv64im_core_if_id