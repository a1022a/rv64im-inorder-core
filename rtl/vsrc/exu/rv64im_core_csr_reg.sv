`include "rv64im_core_defines.sv"

module rv64im_core_csr_reg (
    input  wire [2:0] i_cr_intr_source, //2:外部中断 //1:软件中断 //0:计时器中断
    output wire [2:0] o_cr_intr_req,

    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_cr_wdata,
    input  wire i_cr_wen,
    input  wire [11:0] i_cr_addr,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_cr_rdata,

    input  wire i_cr_intr_wen,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_cr_intr_mstatus,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_cr_intr_mepc,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_cr_intr_mcause,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_cr_intr_mtval,

    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_cr_intr_mstatus,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_cr_intr_mtvec,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_cr_intr_mepc,

    input  wire clk,
    input  wire rstn
);
    //异常处理有关
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mstatus;    //0x300 wr 状态寄存器（MTE/MIPE）
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mtvec;      //0x305 wr 异常入口地址
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mepc;       //0x341 wr 异常返回地址
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mcause;     //0x342 wr 异常原因
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mtval;      //0x343 wr 异常值（地址、指令）
    
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mie;        //0x304 wr 中断使能寄存器 
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mip;        //0x304 r 中断等待寄存器

    wire [31:0] mcycle;    //0xc00 r
    wire [31:0] mcycleh;   //0xc80 r
    reg  [63:0] cycle;
    always @ (posedge clk) begin
        if (rstn == 1'b0) begin
            cycle <= 64'b0;
        end else begin
            cycle <= cycle + 1'b1;
        end
    end
    assign mcycle = cycle[31:0];
    assign mcycleh = cycle[63:32];

    assign  o_cr_rdata = ({`RV64IM_CORE_DATA_WIDTH{i_cr_addr==12'h300}} & mstatus)
                        |({`RV64IM_CORE_DATA_WIDTH{i_cr_addr==12'h305}} & mtvec)
                        |({`RV64IM_CORE_DATA_WIDTH{i_cr_addr==12'h341}} & mepc)
                        |({`RV64IM_CORE_DATA_WIDTH{i_cr_addr==12'h342}} & mcause)
                        |({`RV64IM_CORE_DATA_WIDTH{i_cr_addr==12'h343}} & mtval)
                        |({`RV64IM_CORE_DATA_WIDTH{i_cr_addr==12'h304}} & mie)
                        |({`RV64IM_CORE_DATA_WIDTH{i_cr_addr==12'h344}} & mip)
                        |({`RV64IM_CORE_DATA_WIDTH{i_cr_addr==12'hc00}} & {32'b0,mcycle})
                        |({`RV64IM_CORE_DATA_WIDTH{i_cr_addr==12'hc80}} & {32'b0,mcycleh})
                        ;

    assign o_cr_intr_mstatus = mstatus;
    assign o_cr_intr_mtvec = mtvec;
    assign o_cr_intr_mepc = mepc;

    wire mstatus_wen = (i_cr_wen&(i_cr_addr==12'h300)) | i_cr_intr_wen;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mstatus_wdata = i_cr_intr_wen ? i_cr_intr_mstatus : i_cr_wdata;
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,64'h0) reg_mstatus(clk, !rstn, mstatus_wdata, mstatus, mstatus_wen);

    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_mtvec(clk,!rstn,i_cr_wdata,mtvec,i_cr_wen&(i_cr_addr==12'h305));

    wire mepc_wen = (i_cr_wen&(i_cr_addr==12'h341)) | i_cr_intr_wen;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mepc_wdata = i_cr_intr_wen ? i_cr_intr_mepc : i_cr_wdata;
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_mepc(clk, !rstn, mepc_wdata, mepc, mepc_wen);

    wire mcause_wen = (i_cr_wen&(i_cr_addr==12'h342)) | i_cr_intr_wen;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mcause_wdata = i_cr_intr_wen ? i_cr_intr_mcause : i_cr_wdata;
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_mcause(clk, !rstn, mcause_wdata, mcause, mcause_wen);

    wire mtval_wen = (i_cr_wen&(i_cr_addr==12'h343)) | i_cr_intr_wen;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mtval_wdata = i_cr_intr_wen ? i_cr_intr_mtval : i_cr_wdata;
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_mtval(clk, !rstn, mtval_wdata, mtval, mtval_wen);

    //mie rw [11:meie 7:mtie 3:msie] default open: 0x888
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,64'h888) reg_mie(clk,!rstn,i_cr_wdata,mie,i_cr_wen&(i_cr_addr==12'h304));
    //mip r [11:meip 7:mtip 3:msip]
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mip_wdata = {{(`RV64IM_CORE_DATA_WIDTH-12){1'b0}},
                                                      i_cr_intr_source[2],3'b0,
                                                      i_cr_intr_source[0],3'b0,
                                                      i_cr_intr_source[1],3'b0
                                                      };
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_mip(clk,!rstn,mip_wdata,mip,1'b1);

    wire time_intr     = mie[7]  & i_cr_intr_source[0];
    wire software_intr = mie[3]  & i_cr_intr_source[1];
    wire external_intr = mie[11] & i_cr_intr_source[2];
    assign o_cr_intr_req = {external_intr, software_intr, time_intr};
endmodule //rv64im_core_csr_reg
