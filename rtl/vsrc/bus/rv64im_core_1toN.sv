`include "rv64im_core_defines.sv"

module rv64im_core_1toN # (
    parameter RW_DATA_WIDTH     = 64,
    parameter NS                = 3, //slave nums
    parameter RW_ADDR_WIDTH     = 32
)(
    input  wire [NS-1:0] i_cs,
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
    output wire [NS-1:0] o_req_vld,
    output wire [NS-1:0] o_wen,
    output wire [RW_ADDR_WIDTH-1:0] o_addr [NS-1:0],
    output wire [RW_DATA_WIDTH-1:0] o_wdata [NS-1:0],
    output wire [ 7:0] o_wmask [NS-1:0],
    input  wire [NS-1:0] i_req_rdy,

    input  wire [NS-1:0] i_rsp_vld,
    input  wire [RW_DATA_WIDTH-1:0] i_rdata [NS-1:0],
    output wire [NS-1:0] o_rsp_rdy,

    input  wire clk,
    input  wire rstn
);
    reg [RW_DATA_WIDTH-1:0] rdata;
    reg [NS-1:0] cs_ff;
    always @( posedge clk) begin
        if(!rstn)begin
            cs_ff <= 'b0;
        end else if(i_m0_req_vld) begin
            cs_ff <= i_cs;
        end
    end    

generate  
    genvar i;  
    for (i=0; i<NS; i=i+1) begin : u_bus
        assign o_req_vld[i] = i_cs[i] & i_m0_req_vld;
        assign o_rsp_rdy[i] = cs_ff[i] & i_m0_rsp_rdy;
        assign o_wen[i] = i_m0_wen;
        assign o_addr[i]  = i_m0_addr;
        assign o_wdata[i] = i_m0_wdata;
        assign o_wmask[i] = i_m0_wmask;
    end
endgenerate


//output    
    assign o_m0_req_rdy = |(i_cs[NS-1:0] & i_req_rdy[NS-1:0]);
    assign o_m0_rsp_vld = |(cs_ff[NS-1:0] & i_rsp_vld[NS-1:0]);
    assign o_m0_rdata    = rdata;

    always @(*) begin
        rdata = {RW_DATA_WIDTH{1'b0}};    
        for (integer ii=0; ii<NS; ii=ii+1) begin : u_data
            rdata = rdata | {RW_DATA_WIDTH{cs_ff[ii]}} & i_rdata[ii][RW_DATA_WIDTH-1:0];
        end
    end

endmodule // rv64im_core_lsu1to2
