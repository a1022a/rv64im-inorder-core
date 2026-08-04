`include "rv64im_core_defines.sv"

module rv64im_core_Nto1 # (
    parameter RW_DATA_WIDTH     = 64,
    parameter WMASK             = 8-1,
    parameter NS                = 3, //slave nums
    parameter RW_ADDR_WIDTH     = 32
)(
//m0 interface
    input  wire [NS-1:0] m_req_vld,
    input  wire [NS-1:0] m_wen,
    input  wire [RW_ADDR_WIDTH-1:0] m_addr[NS-1:0] ,
    input  wire [RW_DATA_WIDTH-1:0] m_wdata[NS-1:0] ,
    input  wire [WMASK:0] m_wmask[NS-1:0],
    output wire [NS-1:0] m_req_rdy,

    input  wire [NS-1:0] m_rsp_rdy,
    output wire [RW_DATA_WIDTH-1:0] m_rdata[NS-1:0] ,
    output wire [NS-1:0] m_rsp_vld,
//s0 interface
    output wire s_req_vld,
    output wire s_wen,
    output wire [RW_ADDR_WIDTH-1:0] s_addr,
    output wire [RW_DATA_WIDTH-1:0] s_wdata,
    output wire [WMASK:0] s_wmask,
    input  wire s_req_rdy,

    input  wire s_rsp_vld,
    input  wire [RW_DATA_WIDTH-1:0] s_rdata,
    output wire s_rsp_rdy,

    input  wire clk,
    input  wire rstn
);
    reg [RW_ADDR_WIDTH-1:0] addr;
    reg [WMASK-1:0] wmask;
    reg [RW_DATA_WIDTH-1:0] wdata;
    reg [RW_DATA_WIDTH-1:0] rdata;

	wire [NS-1:0] cs;
    reg  [NS-1:0] cs_ff;

    always @( posedge clk) begin
        if(!rstn)begin
            cs_ff <= 'b0;
		end else if((|m_req_vld) & s_req_rdy) begin
            cs_ff <= cs;
        end
    end    

    
generate for (genvar i=1; i<NS; i=i+1) begin : u_cs
	assign cs[i] = m_req_vld[i] & ~(|cs[i-1:0]);
end
endgenerate
    assign cs[0] = m_req_vld[0];


//output    
generate for (genvar i=0; i<NS; i=i+1) begin : u_bus
    assign m_req_rdy[i] = cs[i] & s_req_rdy;
    assign m_rsp_vld[i] = cs_ff[i] & s_rsp_vld;
    assign m_rdata[i]    = {RW_DATA_WIDTH{cs_ff[i]}} & s_rdata[RW_ADDR_WIDTH-1:0];
end
endgenerate

    always @(*) begin
        addr  = {RW_ADDR_WIDTH{1'b0}};    
        wdata = {RW_DATA_WIDTH{1'b0}};    
        wmask = {WMASK{1'b0}};      
        for (integer ii=0; ii<NS; ii=ii+1) begin : u_wdata
            addr  = addr  | {RW_ADDR_WIDTH{cs[ii]}} & m_addr[ii][RW_ADDR_WIDTH-1:0];
            wdata = wdata | {RW_DATA_WIDTH{cs[ii]}} & m_wdata[ii][RW_DATA_WIDTH-1:0];
            wmask = wmask | {WMASK{cs[ii]}} & m_wdata[ii][WMASK:0];
        end
    end

    assign s_wen   = |(cs[NS-1:0] & m_wen[NS-1:0]);
    assign s_addr  = addr;
    assign s_wdata = wdata;
    assign s_wmask = wmask;
    assign s_req_vld = |(cs[NS-1:0] & m_req_vld[NS-1:0]);
    assign s_rsp_rdy = |(cs_ff[NS-1:0] & m_rsp_rdy[NS-1:0]);

endmodule // rv64im_core_lsu1to2
