`include "rv64im_core_defines.sv"

module rv64im_core_clint (
    //mem
    input  wire i_clt_req_vld,
    input  wire i_clt_wen,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_clt_addr,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_clt_wdata,
    input  wire [7:0] i_clt_wmask,
    output wire o_clt_req_rdy,

    input  wire i_clt_rsp_rdy,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_clt_rdata,
    output wire o_clt_rsp_vld,

    output wire o_clt_msip,
    output wire o_clt_mtip,
//    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_clt_mtime,

    input  wire clk,
    input  wire rstn
);
    //base addr 0x20000000
    //offset addr:
        //msip : 0x0
        //mtimecmp : 0x4000
        //mtime : 0x3ff8
    wire [31:0] msip;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mtimecmp;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mtime;

    wire mtime_cs    = (i_clt_req_vld & o_clt_req_rdy) & (i_clt_addr == 64'h20003ff8);
    wire mtimecmp_cs = (i_clt_req_vld & o_clt_req_rdy) & (i_clt_addr == 64'h20004000);
    wire msip_cs     = (i_clt_req_vld & o_clt_req_rdy) & (i_clt_addr == 64'h20000000);

    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mtime_next = (mtime_cs & i_clt_wen) ? i_clt_wdata : mtime+1;
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_mtime(clk, !rstn, mtime_next, mtime, 1'b1);

    wire mtimecmp_wen = (mtimecmp_cs & i_clt_wen);
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,64'hffff_ffff_ffff_ffff) reg_mtimecmp(clk, !rstn, i_clt_wdata, mtimecmp, mtimecmp_wen);

    wire msip_wen = (msip_cs & i_clt_wen);
    wire [31:0] msip_next = {31'b0,i_clt_wdata[0]};
    rv64im_core_reg #(32,0) reg_msip(clk, !rstn, msip_next, msip, msip_wen);

    wire [`RV64IM_CORE_DATA_WIDTH-1:0] rdata_next = ({`RV64IM_CORE_DATA_WIDTH{msip_cs     & !i_clt_wen}} & {32'b0,msip}) 
                                        | ({`RV64IM_CORE_DATA_WIDTH{mtimecmp_cs & !i_clt_wen}} & mtimecmp)
                                        | ({`RV64IM_CORE_DATA_WIDTH{mtime_cs    & !i_clt_wen}} & mtime)
                                        ;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] rdata;
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_rdata(clk, !rstn, rdata_next, rdata, (msip_cs | mtimecmp_cs | mtime_cs));

    reg cnt;
    always @(posedge clk ) begin
        if (!rstn) begin
            cnt <= 0;
        end else if(i_clt_req_vld & o_clt_req_rdy) begin
            cnt <= 1;
        end else if(o_clt_rsp_vld & i_clt_rsp_rdy) begin
            cnt <= 0;
        end
    end

    assign o_clt_req_rdy = (cnt==0);
    assign o_clt_rsp_vld = (cnt==1);
    assign o_clt_rdata = rdata;

    assign o_clt_msip = msip[0];
    assign o_clt_mtip = (mtime >= mtimecmp);


endmodule //rv64im_core_clint
