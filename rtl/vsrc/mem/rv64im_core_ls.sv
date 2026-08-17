`include "rv64im_core_defines.sv"

module rv64im_core_ls (
    input  wire i_ls_flush,
    input  wire i_ls_stall,
    input  wire i_ls_mem_req,
    input  wire i_ls_mem_rw_ctrl,
    input  wire [4:0] i_ls_mem_rw_len,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_ls_mem_addr,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_ls_rs2_data,

    input  wire [4:0] i_ls_rd_index,
    input  wire i_ls_rd_wen,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_ls_rd_data,

    input wire mul_op,
    input wire [1:0] mul_mode,  //{use hign 64bit, use low 32bit}
    input wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] mul_cas_res1,
    input wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] mul_cas_res2,


    output wire o_ls_mem_stall,
    output wire o_ls_addr_stall,

    output wire o_ls_rd_wen,
    output wire [4:0] o_ls_rd_index,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_ls_memtord_data,

    //to idu
    output wire o_ls_idu_wen, 
    output wire [4:0] o_ls_idu_index,   
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_ls_idu_data,
    output wire o_ls_load_bypass_vld,

    //to bus
    output wire o_ls_req_vld,
    output wire o_ls_wen,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_ls_addr,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_ls_wdata,
    output wire [ 7:0] o_ls_wmask,
    input  wire i_ls_req_rdy,

    input  wire i_ls_rsp_vld,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_ls_rdata,
    output wire o_ls_rsp_rdy,

    //load data
    input  wire i_ls_load_ff,
    input  wire [4:0] i_ls_len_ff,
    input  wire i_ls_mem_req_ff,

    input  wire clk,
    input  wire rstn
);
    wire addr_shake = i_ls_req_rdy & o_ls_req_vld;
    wire data_shake = o_ls_rsp_rdy & i_ls_rsp_vld;
    reg [`RV64IM_CORE_DATA_WIDTH-1:0] addr_ff;
    reg [`RV64IM_CORE_DATA_WIDTH-1:0] rdata_r;
    reg rsp_rdy;

//=== wirte data begin ===\\
    wire str_index0 = i_ls_mem_addr[2:0] == 3'b000;
    wire str_index1 = i_ls_mem_addr[2:0] == 3'b001;
    wire str_index2 = i_ls_mem_addr[2:0] == 3'b010;
    wire str_index3 = i_ls_mem_addr[2:0] == 3'b011;
    wire str_index4 = i_ls_mem_addr[2:0] == 3'b100;
    wire str_index5 = i_ls_mem_addr[2:0] == 3'b101;
    wire str_index6 = i_ls_mem_addr[2:0] == 3'b110;
    wire str_index7 = i_ls_mem_addr[2:0] == 3'b111;

    wire [63:0] rs2_data = i_ls_rs2_data;
    wire [63:0] sb_res =  {{8{str_index7}},{8{str_index6}},{8{str_index5}},{8{str_index4}},{8{str_index3}},{8{str_index2}},{8{str_index1}},{8{str_index0}}} 
                        & {rs2_data[7:0],   rs2_data[7:0],   rs2_data[7:0],   rs2_data[7:0],   rs2_data[7:0],   rs2_data[7:0],   rs2_data[7:0],   rs2_data[7:0]};
                        
    wire [63:0] sh_res =  {{16{str_index6}},{16{str_index4}},{16{str_index2}},{16{str_index0}}} 
                        & {rs2_data[15:0],   rs2_data[15:0],   rs2_data[15:0],   rs2_data[15:0]};

    wire [63:0] sw_res =  {{32{str_index4}},{32{str_index0}}} 
                        & {rs2_data[31:0],   rs2_data[31:0]};

    wire [63:0] sd_res = {64{str_index0}} & rs2_data;

    wire [7:0] mem_wmask =    ({8{i_ls_mem_rw_len[0]}} & {str_index7,str_index6,str_index5,str_index4,str_index3,str_index2,str_index1,str_index0})
                            | ({8{i_ls_mem_rw_len[1]}} & { {2{str_index6}},{2{str_index4}},{2{str_index2}},{2{str_index0}} })
                            | ({8{i_ls_mem_rw_len[2]}} & { {4{str_index4}},{4{str_index0}} })
                            | ({8{i_ls_mem_rw_len[3]}} & {8{str_index0}})
                            ;  
    wire [63:0] mem_wdata =   ({64{i_ls_mem_rw_len[0]}} & sb_res)
                            | ({64{i_ls_mem_rw_len[1]}} & sh_res)
                            | ({64{i_ls_mem_rw_len[2]}} & sw_res)
                            | ({64{i_ls_mem_rw_len[3]}} & sd_res)
                            ;  
//=== wirte data end ===\\
  
//=== read data start ===\\
//read data : lsu pipe , only care external stall , no external flush
    reg data_shake_done;
    wire data_shake_done_next = data_shake_done ? i_ls_stall : data_shake & i_ls_stall;
    wire data_shake_done_en   = data_shake | data_shake_done;
    always @(posedge clk ) begin
      if (!rstn) begin
        data_shake_done <= 1'b0;
      end else if(data_shake_done_en) begin
        data_shake_done <= data_shake_done_next;
      end
    end

    always @(posedge clk ) begin
      if (!rstn) begin
        rdata_r <= 'b0;
      end else if(data_shake) begin
        rdata_r <= i_ls_rdata;
      end
    end  

    always @(posedge clk ) begin
      if (!rstn) begin
        addr_ff <= 'b0;
      end else if(addr_shake) begin
        addr_ff <= i_ls_mem_addr;
      end
    end

    wire addr_index0 = addr_ff[2:0] == 3'b000;
    wire addr_index1 = addr_ff[2:0] == 3'b001;
    wire addr_index2 = addr_ff[2:0] == 3'b010;
    wire addr_index3 = addr_ff[2:0] == 3'b011;
    wire addr_index4 = addr_ff[2:0] == 3'b100;
    wire addr_index5 = addr_ff[2:0] == 3'b101;
    wire addr_index6 = addr_ff[2:0] == 3'b110;
    wire addr_index7 = addr_ff[2:0] == 3'b111;

    wire sign_ext = i_ls_len_ff[4];
    wire [63:0] mem_rdata =  data_shake_done ? rdata_r : i_ls_rdata ;
    wire [63:0] lb_res =  ({64{addr_index0}} & {{56{i_ls_len_ff[0] & sign_ext & mem_rdata[7]}} ,mem_rdata[7:0] })
                        | ({64{addr_index1}} & {{56{i_ls_len_ff[0] & sign_ext & mem_rdata[15]}},mem_rdata[15:8]})
                        | ({64{addr_index2}} & {{56{i_ls_len_ff[0] & sign_ext & mem_rdata[23]}},mem_rdata[23:16]})
                        | ({64{addr_index3}} & {{56{i_ls_len_ff[0] & sign_ext & mem_rdata[31]}},mem_rdata[31:24]})
                        | ({64{addr_index4}} & {{56{i_ls_len_ff[0] & sign_ext & mem_rdata[39]}},mem_rdata[39:32]})
                        | ({64{addr_index5}} & {{56{i_ls_len_ff[0] & sign_ext & mem_rdata[47]}},mem_rdata[47:40]})
                        | ({64{addr_index6}} & {{56{i_ls_len_ff[0] & sign_ext & mem_rdata[55]}},mem_rdata[55:48]})
                        | ({64{addr_index7}} & {{56{i_ls_len_ff[0] & sign_ext & mem_rdata[63]}},mem_rdata[63:56]})
                        ;
    wire [63:0] lh_res =  ({64{addr_index0}} & {{48{i_ls_len_ff[1] & sign_ext & mem_rdata[15]}},mem_rdata[15:0] })
                        | ({64{addr_index2}} & {{48{i_ls_len_ff[1] & sign_ext & mem_rdata[31]}},mem_rdata[31:16]})
                        | ({64{addr_index4}} & {{48{i_ls_len_ff[1] & sign_ext & mem_rdata[47]}},mem_rdata[47:32]})
                        | ({64{addr_index6}} & {{48{i_ls_len_ff[1] & sign_ext & mem_rdata[63]}},mem_rdata[63:48]})
                        ; 
    wire [63:0] lw_res =  ({64{addr_index0}} & {{32{i_ls_len_ff[2] & sign_ext & mem_rdata[31]}},mem_rdata[31:0]})
                        | ({64{addr_index4}} & {{32{i_ls_len_ff[2] & sign_ext & mem_rdata[63]}},mem_rdata[63:32]})
                        ;
    wire [63:0] ld_res = mem_rdata;
//=== read data end ===\\

  //to pipe
    wire data_stall = i_ls_mem_req_ff & rsp_rdy & !i_ls_rsp_vld;   //exu pipe stall
    wire addr_stall = i_ls_mem_req & o_ls_req_vld & !i_ls_req_rdy; //lsu pipe stall
  assign o_ls_mem_stall  = data_stall;
  assign o_ls_addr_stall = addr_stall;
  //to wb
    wire [64-1:0] alutord_data;
    assign o_ls_rd_index = i_ls_rd_index;
    assign o_ls_rd_wen   = i_ls_mem_req_ff ? i_ls_load_ff : i_ls_rd_wen; //when stall, reg signal will keep

    wire [`RV64IM_CORE_DATA_WIDTH-1:0] memtord_data;
    assign memtord_data        =   ({64{i_ls_len_ff[0]}}  & lb_res)
                               |  ({64{i_ls_len_ff[1]}}  & lh_res)
                               |  ({64{i_ls_len_ff[2]}}  & lw_res)
                               |  ({64{i_ls_len_ff[3]}}  & ld_res)
                               ;
    assign o_ls_memtord_data =  o_ls_idu_data;

  //to idu
    wire [127:0] mul_res = mul_cas_res1[127:0] + mul_cas_res2[127:0];
    assign alutord_data  =   {64{mul_op & mul_mode[0]}}       & {{32{mul_res[31]}}, mul_res[31:0]}
                           | {64{mul_op & mul_mode[1]}}       & {mul_res[127:64]}
                           | {64{mul_op & ~(|mul_mode[1:0])}} & {mul_res[63:0]}
                           | {64{~mul_op}}                    & {i_ls_rd_data[63:0]}
                           ;

    assign o_ls_idu_wen   = i_ls_rd_wen;
    assign o_ls_idu_index = i_ls_rd_index;
    assign o_ls_idu_data  = i_ls_mem_req_ff ? memtord_data : alutord_data;
    assign o_ls_load_bypass_vld = i_ls_mem_req_ff & i_ls_load_ff
                                & (i_ls_rsp_vld | data_shake_done);

  //to bus
  /*问题：访存完成后，流水线还在stall转态应如何；访存接口时序问题；*/
//addr phase
  //use signal of exu pipe
  //condition of req_vld : 1. no data_stall 2. no intr flush 3. when addr_shake, exu pipe done
    wire req_vld = i_ls_mem_req & !data_stall & !i_ls_flush;

    assign o_ls_req_vld = req_vld;
    assign o_ls_wen      = !i_ls_mem_rw_ctrl;
    assign o_ls_addr     = {i_ls_mem_addr[63:3],3'b000};
    assign o_ls_wmask    = mem_wmask;
    assign o_ls_wdata    = mem_wdata;

//data phase
    always @(posedge clk ) begin
      if (!rstn) begin
        rsp_rdy <= 1'b0;
      end else if(addr_shake) begin
        rsp_rdy <= 1'b1;
      end else if(data_shake) begin
        rsp_rdy <= 1'b0;
      end
    end
    assign o_ls_rsp_rdy = rsp_rdy;

endmodule //lsu
