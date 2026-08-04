`include "rv64im_core_defines.sv"

module rv64im_core_2to1 #(
    parameter RW_DATA_WIDTH     = 64,
    parameter RW_ADDR_WIDTH     = 32
)(
    //m0
    input  wire i_m0_valid,
    input  wire i_m0_wen,
    input  wire [RW_ADDR_WIDTH-1:0] i_m0_addr,
    input  wire [RW_DATA_WIDTH-1:0] i_m0_wdata,
    input  wire [7:0] i_m0_wmask,
    output wire [RW_DATA_WIDTH-1:0] o_m0_rdata,
    output wire o_m0_ready,
    //m1
    input  wire i_m1_valid,
    input  wire i_m1_wen,
    input  wire [RW_ADDR_WIDTH-1:0] i_m1_addr,
    input  wire [RW_DATA_WIDTH-1:0] i_m1_wdata,
    input  wire [7:0] i_m1_wmask,
    output wire [RW_DATA_WIDTH-1:0] o_m1_rdata,
    output wire o_m1_ready,
    //s0
    output wire o_abr_valid,
    output wire o_abr_wen,
    output wire [RW_ADDR_WIDTH-1:0] o_abr_addr,
    output wire [RW_DATA_WIDTH-1:0] o_abr_wdata,
    output wire [7:0] o_abr_wmask,
    input  wire [RW_DATA_WIDTH-1:0] i_abr_rdata,
    input  wire i_abr_ready
);
    //m0 and m1 can't be one at same time
    assign o_abr_valid = i_m0_valid | i_m1_valid; 
    assign o_abr_wen   = i_m0_valid & i_m0_wen | i_m1_valid & i_m1_wen;
    assign o_abr_addr  = i_m0_valid ? i_m0_addr  : i_m1_addr;
    assign o_abr_wdata = i_m0_valid ? i_m0_wdata : i_m1_wdata;
    assign o_abr_wmask = i_m0_valid ? i_m0_wmask : i_m1_wmask;

    assign o_m0_rdata  = i_m0_valid ? i_abr_rdata : 0;
    assign o_m1_rdata  = i_m1_valid ? i_abr_rdata : 0;

    assign o_m0_ready  = i_m0_valid ? i_abr_ready : 0;
    assign o_m1_ready  = i_m1_valid ? i_abr_ready : 0;

endmodule //interface_bus
