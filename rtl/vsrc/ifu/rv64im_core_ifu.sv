`include "rv64im_core_defines.sv"

module rv64im_core_ifu (
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_if_rdata,    //form cache
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_if_addr,     //取指令的地址

    input  wire i_if_req_rdy,
    output wire o_if_req_vld,

    output wire o_if_rsp_rdy,
    input  wire i_if_rsp_vld,

    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_if_flush_addr,
    input  wire i_if_flush,
    input  wire i_if_stall,
    
    output wire o_if_vld,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_if_pc,
    output wire [`RV64IM_CORE_INST_WIDTH-1:0] o_if_inst,  //to idu
`ifdef SAT_CNT
    input  wire i_if_bx_cond,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_if_bx_pc,
    input  wire i_if_bx_pt,
    output wire o_if_predict_pt,
`ifdef RAS
    input  wire i_if_bx_push,
    input  wire i_if_bx_pop,
`endif
`endif
    input  wire clk,
    input  wire rstn
);
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] pc;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] pc_next; 

    wire addr_shake = i_if_req_rdy & o_if_req_vld;
    wire data_shake = o_if_rsp_rdy & i_if_rsp_vld;
//===sp begin===
    wire [`RV64IM_CORE_INST_WIDTH-1:0] inst = o_if_inst;
    wire uncond_jump  = (inst[6:0] == 7'b1101111);
    wire cond_bxx     = (inst[6:0] == 7'b1100011) & (inst[14:12] != 3'b010) & (inst[14:12]!=3'b011);
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] pc_offset = uncond_jump ? {{43{inst[31]}},inst[31], inst[19:12], inst[20], inst[30:21], 1'b0} : //jal
                                                                   {{51{inst[31]}},inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}     //bxx 
                                                                  ;  
`ifdef SP    
    wire sp_hit = uncond_jump | cond_bxx & inst[31]; //offset < 0 ,sp_hit                                                    
`endif

`ifdef SAT_CNT
    wire pred_pt;
    wire pred_vld;

    wire cond_pt = pred_vld & pred_pt & cond_bxx;
    wire dirbrn_pt = cond_bxx ? (pred_vld ? cond_pt : inst[31]) : uncond_jump;
 
rv64im_core_satcnt u_rv64im_core_satcnt(
    .i_bx_cond  ( i_if_bx_cond ),
    .i_bx_pc    ( i_if_bx_pc[`RV64IM_CORE_DATA_WIDTH-1:2]),
    .i_bx_pt    ( i_if_bx_pt   ),
    .i_pred_pc  ( pc_next[`RV64IM_CORE_DATA_WIDTH-1:2]),
    .o_pred_pt  ( pred_pt    ),
    .o_pred_vld ( pred_vld   ),
    .i_pred_en  ( addr_shake   ),
    .clk        ( clk        ),
    .rstn       ( rstn       )
);
    assign o_if_predict_pt = dirbrn_pt;

`ifdef RAS
    wire pop  = (inst[6:0] == 7'b1100111) & (inst[14:12]==3'b000) & ((inst[19:15] == 5'd1) | (inst[19:15] == 5'd5)) & (inst[19:15] != inst[11:7]);   //jalr rs1=x1/x5 rs1!=rd 
    wire pop_vld;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] pop_tgt;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] push_tgt = i_if_bx_pc + 4;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] ret_tgt  = i_if_bx_push ? push_tgt : pop_tgt;
rv64im_core_ras u_rv64im_core_ras(
    .i_bx_push  ( i_if_bx_push  ),
    .i_bx_pop   ( i_if_bx_pop   ),
    .i_push_tgt ( push_tgt   ),
    .o_pop_vld  ( pop_vld    ),
    .o_pop_tgt  ( pop_tgt    ),
    .clk        ( clk        ),
    .rstn       ( rstn       )
);
`endif
`endif

//===sp end===
/*
    关键问题：
    不同状态时的stall（ex和mem阶段）和flush（跳转和中断异常）问题；
    为满足SRAM时序，采用addr phase 和data phase 相分离的形式；

*/

//addr phase
/*
    stall有效时，不发送addr请求
    flush有效时: 若addr_shake==1，则冲刷地址被发送； 若addr_shake==0，则将flush相关信号保存；    
*/
    reg flush;
    always @(posedge clk ) begin
        if (!rstn) begin
            flush <= 'b0;
        end else if(i_if_flush & !addr_shake) begin
            flush <= 'b1;
        end else if(flush & addr_shake) begin
            flush <= 'b0;
        end
    end
    reg [`RV64IM_CORE_DATA_WIDTH-1:0] flush_addr;
    always @(posedge clk ) begin
        if (!rstn) begin
            flush_addr <= 'b0;
        end else if(i_if_flush) begin
            flush_addr <= i_if_flush_addr;
        end
    end
    //wire [3:0] nseq_pc_sel;
`ifdef TIME_OPT
    assign pc_next = 
`else
    assign pc_next = i_if_flush  ? i_if_flush_addr : 
`endif
                                                   flush       ? flush_addr      :
`ifdef RAS
                                                   pop & pop_vld ? ret_tgt       :
`endif 
`ifdef SP
                                                   sp_hit      ? pc+pc_offset    :
`endif
`ifdef SAT_CNT
                                                   dirbrn_pt   ? pc+pc_offset    :
`endif                                                
                                                                 pc+4;
//
    wire if_stall  = i_if_stall & !i_if_flush;
    wire pc_en     = addr_shake;
`ifdef TIME_OPT
    assign o_if_req_vld = ~(o_if_rsp_rdy & ~i_if_rsp_vld) & ~(i_if_stall | i_if_flush); 
`else
    assign o_if_req_vld = ~(o_if_rsp_rdy & ~i_if_rsp_vld) & ~(if_stall);
`endif
    assign o_if_addr = {pc_next[`RV64IM_CORE_DATA_WIDTH-1:2],2'b00};
//data phase
/*
    问题：什么时候接收请求；来flush和stall时如何处理；
    若stall有效时，若data已到，保存data信号;
    若flush有效时，data未到，不发送flush地址，保存flush信号;
    若flush有效时，data已到，可发送addr请求， 则舍去当前data；
*/
    wire [`RV64IM_CORE_INST_WIDTH-1:0] inst_of_cache;
    reg  [`RV64IM_CORE_INST_WIDTH-1:0] inst_of_stall;
    reg  data_stall_vld;
    reg  rsp_rdy;

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            data_stall_vld <= 0;
            inst_of_stall  <= 0;
        end else if(data_shake     & if_stall) begin
            data_stall_vld <= 1;
            inst_of_stall  <= inst_of_cache;
        end else if(data_stall_vld & ~if_stall) begin
            data_stall_vld <= 0;
        end
    end

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            rsp_rdy <= 0;
        end else if (addr_shake)begin
            rsp_rdy <= 1'b1;
        end else if (data_shake)begin
            rsp_rdy <= 1'b0;
        end
    end

    assign o_if_rsp_rdy = rsp_rdy;
    assign inst_of_cache = (pc[2] ? i_if_rdata[63:32]:i_if_rdata[31:0]); 


//有效信号传递
    wire   inst_ok = (data_shake | data_stall_vld) & ~i_if_stall & ~(i_if_flush | flush);    //存在flush时，当前得到的数据无效；
    assign o_if_inst = inst_ok ? (data_stall_vld ? inst_of_stall : inst_of_cache) : `RV64IM_CORE_INST_NOP;
    assign o_if_pc   = inst_ok ? pc : 0;     //指令无效时传递0地址；
    assign o_if_vld  = inst_ok;

    rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,`RV64IM_CORE_PC_RESET_ADDR) pc_reg(clk,!rstn,pc_next,pc,pc_en);
endmodule
