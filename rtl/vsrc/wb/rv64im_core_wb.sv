`include "rv64im_core_defines.sv"

module rv64im_core_wb (

    input  wire [4:0] i_wb_rd_index,
    input  wire i_wb_rd_wen,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_wb_memtord_data,

    output wire [4:0] o_wb_rd_index,
    output wire o_wb_rd_wen,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_wb_rd_data

);
    assign o_wb_rd_index=i_wb_rd_index;
    assign o_wb_rd_wen  = i_wb_rd_wen;
    assign o_wb_rd_data = i_wb_memtord_data;

endmodule //rv64im_core_if_id