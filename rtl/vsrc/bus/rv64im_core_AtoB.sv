`include "rv64im_core_defines.sv"

module rv64im_core_AtoB # (
    parameter RW_DATA_WIDTH     = 64,
    parameter RW_ADDR_WIDTH     = 32
)(
//m0 interface
    input  wire i_m0_req_vld,
    input  wire i_m0_wen,
    input  wire [RW_ADDR_WIDTH-1:0] i_m0_addr,
    input  wire [RW_DATA_WIDTH-1:0] i_m0_wdata,
    input  wire [7:0] i_m0_wmask,
    output wire o_m0_req_rdy,

    input  wire i_m0_rsp_rdy,
    output wire [RW_DATA_WIDTH-1:0] o_m0_rdata,
    output wire o_m0_rsp_vld,
//s0 interface
    output wire o_abr_valid,
    output wire o_abr_wen,
    output wire [RW_ADDR_WIDTH-1:0] o_abr_addr,
    output wire [RW_DATA_WIDTH-1:0] o_abr_wdata,
    output wire [7:0] o_abr_wmask,
    input  wire [RW_DATA_WIDTH-1:0] i_abr_rdata,
    input  wire i_abr_ready,

    input  wire clk,
    input  wire rstn
);
    reg req_rdy;
    reg valid;
    reg [RW_DATA_WIDTH-1:0] rdata;
    reg [RW_ADDR_WIDTH-1:0] addr;
    reg [RW_DATA_WIDTH-1:0] wdata;
    reg [8-1:0] wmask;
    reg wen;

    always @( posedge clk) begin
        if(i_m0_req_vld & o_m0_req_rdy) begin
            addr  <= i_m0_addr;
            wdata <= i_m0_wdata;
            wmask <= i_m0_wmask;
            wen   <= i_m0_wen;
        end
    end    

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            req_rdy <= 1'b1;  //access the first req
        end else if(i_m0_req_vld & o_m0_req_rdy) begin
            req_rdy <= 1'b0;
        end else if(o_m0_rsp_vld & i_m0_rsp_rdy) begin
            req_rdy <= 1'b1;
        end
    end        

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            valid <= 1'b0;
        end else if(i_m0_req_vld & o_m0_req_rdy) begin
            valid <= 1'b1;
        end else if(o_abr_valid & i_abr_ready) begin
            valid <= 1'b0;
        end
    end        

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            rdata <= 'b0;
        end else if(o_abr_valid & i_abr_ready) begin
            rdata <= i_abr_rdata;
        end
    end        

    assign o_abr_valid = valid;
    assign o_abr_wen   = wen;
    assign o_abr_addr  = addr;
    assign o_abr_wdata = wdata;
    assign o_abr_wmask = wmask;

    assign o_m0_req_rdy = req_rdy;
// !req_rdy : data stall  !valid : rdata has arrive
    assign o_m0_rsp_vld = ~req_rdy & ((o_abr_valid & i_abr_ready) | ~valid);
    assign o_m0_rdata    = i_abr_ready ? i_abr_rdata : rdata;
endmodule // rv64im_core_lsu1to2
