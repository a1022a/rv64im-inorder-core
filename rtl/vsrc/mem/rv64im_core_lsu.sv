`include "rv64im_core_defines.sv"

module rv64im_core_lsu (
    input  wire [4:0] i_lsu_rd_index,
    input  wire i_lsu_rd_wen,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_lsu_rd_data,

    input wire i_lsu_req,
    input wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_lsu_addr,
    input wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_lsu_rs2_data,
    input wire i_lsu_rw_ctrl,
    input wire [4:0] i_lsu_rw_len,

    input wire ex_ls_mul_op,
    input wire [1:0] ex_ls_mul_mode,  //{use hign 64bit, use low 32bit}
    input wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] ex_ls_mul_cas_res1,
    input wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] ex_ls_mul_cas_res2,

    input wire i_lsu_flush,              // 流水线冲刷标志
    input wire i_lsu_stall,              // 流水线等待标志

    output wire o_lsu_stall,
    output wire o_lsu_addr_stall,

    output wire [4:0] o_lsu_rd_index,
    output wire o_lsu_rd_wen,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_lsu_memtord_data,

    //to idu
    output wire o_lsu_idu_wen, 
    output wire [4:0] o_lsu_idu_index,   
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_lsu_idu_data,
    output wire o_lsu_load_bypass_vld,
    //to bus
    output wire o_lsu_req_vld,
    output wire o_lsu_wen,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_lsu_addr,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_lsu_wdata,
    output wire [ 7:0] o_lsu_wmask,
    input  wire i_lsu_req_rdy,

    input  wire i_lsu_rsp_vld,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_lsu_rdata,
    output wire o_lsu_rsp_rdy,

    input clk,
    input rstn
);

    wire reg_ls_req;
    wire reg_ls_rw_ctrl;
    wire [4:0] reg_ls_rw_len;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] reg_ls_addr;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] reg_ls_rs2_data;

    wire [4:0] reg_ls_rd_index;
    wire reg_ls_rd_wen;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] reg_ls_rd_data;

    wire mul_op;
    wire [1:0] mul_mode;  //{use hign 64bit, use low 32bit}
    wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] mul_cas_res1;
    wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] mul_cas_res2;

    wire reset = !rstn | i_lsu_flush;


rv64im_core_ls u_rv64im_core_ls(

  .i_ls_flush        (i_lsu_flush), 
  .i_ls_stall        (i_lsu_stall), 
  .i_ls_mem_req      (i_lsu_req), 
  .i_ls_mem_rw_ctrl  (i_lsu_rw_ctrl  ),
  .i_ls_mem_rw_len   (i_lsu_rw_len   ),
  .i_ls_mem_addr     (i_lsu_addr     ),
  .i_ls_rs2_data     (i_lsu_rs2_data ),

  .i_ls_rd_index     (reg_ls_rd_index     ),
  .i_ls_rd_wen       (reg_ls_rd_wen       ),
  .i_ls_rd_data      (reg_ls_rd_data      ),

  .mul_op            (mul_op),
  .mul_mode          (mul_mode),
  .mul_cas_res1      (mul_cas_res1),
  .mul_cas_res2      (mul_cas_res2),

  .o_ls_mem_stall    (o_lsu_stall    ),
  .o_ls_addr_stall   (o_lsu_addr_stall   ),
  .o_ls_rd_wen       (o_lsu_rd_wen       ),
  .o_ls_rd_index     (o_lsu_rd_index     ),
  .o_ls_memtord_data (o_lsu_memtord_data ),

  .o_ls_idu_wen      (o_lsu_idu_wen      ),
  .o_ls_idu_index    (o_lsu_idu_index    ),
  .o_ls_idu_data     (o_lsu_idu_data     ),
  .o_ls_load_bypass_vld (o_lsu_load_bypass_vld),

  .o_ls_req_vld     ( o_lsu_req_vld    ),
  .o_ls_wen          ( o_lsu_wen         ),
  .o_ls_addr         ( o_lsu_addr        ),
  .o_ls_wdata        ( o_lsu_wdata       ),
  .o_ls_wmask        ( o_lsu_wmask       ),
  .i_ls_req_rdy     ( i_lsu_req_rdy    ),
  .i_ls_rsp_vld     ( i_lsu_rsp_vld    ),
  .i_ls_rdata        ( i_lsu_rdata       ),
  .o_ls_rsp_rdy     ( o_lsu_rsp_rdy    ),

  .i_ls_mem_req_ff   ( reg_ls_req        ),
  .i_ls_load_ff      ( reg_ls_rw_ctrl    ),
  .i_ls_len_ff       ( reg_ls_rw_len     ),
  .clk               ( clk               ),
  .rstn              ( rstn              )

);


    rv64im_core_reg #(5,0) reg_lsu_rd_index(clk,reset,i_lsu_rd_index,reg_ls_rd_index,!i_lsu_stall);
    rv64im_core_reg #(1,0) reg_lsu_rd_wen(clk,reset,i_lsu_rd_wen,reg_ls_rd_wen,!i_lsu_stall);
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_lsu_rd_data(clk,reset,i_lsu_rd_data,reg_ls_rd_data,!i_lsu_stall);

    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_lsu_addr(clk,reset,i_lsu_addr,reg_ls_addr,!i_lsu_stall);
    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) reg_lsu_rs2_data(clk,reset,i_lsu_rs2_data,reg_ls_rs2_data,!i_lsu_stall);

    rv64im_core_reg #(1,0) reg_lsu_rw_ctrl(clk,reset,i_lsu_rw_ctrl,reg_ls_rw_ctrl,!i_lsu_stall);
    rv64im_core_reg #(5,0) reg_lsu_rw_len(clk,reset,i_lsu_rw_len,reg_ls_rw_len,!i_lsu_stall);
    rv64im_core_reg #(1,0) reg_lsu_req(clk,reset,i_lsu_req,reg_ls_req,!i_lsu_stall);

    rv64im_core_reg #(1,0) reg_mul_op(clk,reset,ex_ls_mul_op,mul_op,!i_lsu_stall);
    rv64im_core_reg #(2,0) reg_mul_mode(clk,reset,ex_ls_mul_mode,mul_mode,!i_lsu_stall);
    rv64im_core_reg #((2*`RV64IM_CORE_DATA_WIDTH),0) reg_mul_cas_res1(clk,reset,ex_ls_mul_cas_res1,mul_cas_res1,!i_lsu_stall);
    rv64im_core_reg #((2*`RV64IM_CORE_DATA_WIDTH),0) reg_mul_cas_res2(clk,reset,ex_ls_mul_cas_res2,mul_cas_res2,!i_lsu_stall);


endmodule //lsu
