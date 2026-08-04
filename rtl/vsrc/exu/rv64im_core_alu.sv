`include "rv64im_core_defines.sv"

module rv64im_core_alu
(   //from id
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_alu_pc,
    input  wire [`RV64IM_CORE_INST_WIDTH-1:0] i_alu_inst,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_alu_rs1_data,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_alu_rs2_data,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_alu_imm_data,
    input  wire [4:0] i_alu_rd_index,
    input  wire [`RV64IM_CORE_TYPE_INFO-1:0] i_alu_type_info,    
    input  wire [`RV64IM_CORE_OP_INFO-1  :0] i_alu_op_info,

    input  wire i_alu_flush,              
    input  wire i_alu_stall,

    //for lsu
    input  wire i_alu_addr_stall,

    //to mem
    output wire o_alu_mem_req,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_alu_mem_addr, //mem_req ? mem_addr : rd_wdata
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_alu_mem_rs2_data,
    output wire o_alu_mem_rw_ctrl, //mem_req ? rw_ctrl : rd_wen
    output wire [4:0] o_alu_mem_rw_len, //{signal,64bit,32bit,16bit,8bit}

    output wire o_alu_rd_wen,
    output wire [4:0] o_alu_rd_index,
    
    output wire ex_ls_mul_op,
    output wire [1:0] ex_ls_mul_mode,  //{use hign 64bit, use low 32bit}
    output wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] ex_ls_mul_cas_res1,
    output wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] ex_ls_mul_cas_res2,
    //to pipe_ctrl
    output wire o_alu_stall,
    output wire o_alu_flush,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_alu_flush_addr,

    //to intr
    input  wire i_alu_intr,
    output wire o_alu_intr_ecall,
    output wire o_alu_intr_ebreak,
    output wire o_alu_intr_mret,
    output wire [`RV64IM_CORE_INST_WIDTH-1:0] o_alu_intr_inst,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_alu_intr_pc,
    
    //to idu
    output wire o_alu_idu_wen,
    output wire [4:0] o_alu_idu_index,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_alu_idu_data,
    output wire o_alu_idu_load,
    //csr
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_alu_csr_rdata,
    output wire o_alu_csr_wen,
    output wire [11:0] o_alu_csr_addr,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_alu_csr_wdata,
`ifdef SAT_CNT  
    output wire bx_if_cond      ,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] bx_if_pc        ,
    output wire bx_if_pt        ,
    input  wire if_bx_predict_pt,
`ifdef RAS
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] idu_pc        ,
    output wire bx_if_push,
    output wire bx_if_pop ,
`endif
`endif
    input  wire clk,
    input  wire rstn
);
//dispatch
    //rv64im_core_ALU_INFO
    wire alu_req = i_alu_type_info[0];
    wire add_op , sub_op , sll_op , srl_op , sra_op , slt_op , sltu_op , xor_op , or_op , and_op , op2_imm , op1_pc , res_imm , alu_sext_w;
    assign {add_op , sub_op , sll_op , srl_op , sra_op , slt_op , sltu_op , xor_op , or_op , and_op , op2_imm , op1_pc , res_imm , alu_sext_w} 
    = {`RV64IM_CORE_ALU_INFO{alu_req}} & i_alu_op_info;

    wire [`RV64IM_CORE_DATA_WIDTH-1:0] alu_op1 = op1_pc ? i_alu_pc : i_alu_rs1_data;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] alu_op2 = op2_imm? i_alu_imm_data :  i_alu_rs2_data;

    //mem_info
    wire mem_req = i_alu_type_info[1];
    wire mem_rw_ctrl;
    wire mem_lb;
    wire mem_lh;
    wire mem_lw;
    wire mem_ld;
    wire mem_lbu;
    wire mem_lhu;
    wire mem_lwu;
    wire mem_sb;
    wire mem_sh;
    wire mem_sw;
    wire mem_sd;
    assign o_alu_mem_req = mem_req & (!i_alu_intr); //有异步中断发生时，取消alu向mem的req,防止其向下级传递；
    assign { mem_lb,
             mem_lh,
             mem_lw,
             mem_ld,
             mem_lbu,
             mem_lhu,
             mem_lwu,
             mem_sb,
             mem_sh,
             mem_sw,
             mem_sd,
             o_alu_mem_rw_ctrl} = {`RV64IM_CORE_MEM_INFO{mem_req}} & i_alu_op_info[(`RV64IM_CORE_OP_INFO - 1) -: `RV64IM_CORE_MEM_INFO];
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mem_op1 = i_alu_rs1_data;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mem_op2 = i_alu_imm_data;
    assign o_alu_mem_rw_len[4:0] = {(mem_lw |mem_lh | mem_lb),
                                    (mem_sd | mem_ld),
                                    (mem_sw | mem_lw | mem_lwu),
                                    (mem_sh | mem_lh | mem_lhu),
                                    (mem_sb | mem_lb | mem_lbu)
                                    };

    //bjp_info
    wire bjp_req = i_alu_type_info[2];
    wire beq , bne , blt , bge , bltu , bgeu , jal , jalr;
    assign {beq , bne , blt , bge , bltu , bgeu , jal , jalr} 
    = {`RV64IM_CORE_BJP_INFO{bjp_req}} & i_alu_op_info[(`RV64IM_CORE_OP_INFO - 1) -: `RV64IM_CORE_BJP_INFO];

    wire [`RV64IM_CORE_DATA_WIDTH-1:0] bjp_op1 = jalr ? i_alu_rs1_data : i_alu_pc;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] bjp_op2 = i_alu_imm_data;

    wire [`RV64IM_CORE_DATA_WIDTH-1:0] bjp_cmp_op1 = i_alu_rs1_data;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] bjp_cmp_op2 = i_alu_rs2_data;

    //muldiv_info
    wire muldiv_req = i_alu_type_info[3];
    wire mul , mulh , mulhsu , mulhu , div , divu , rem , remu , md_sext_w;
    assign {mul , mulh , mulhsu , mulhu , div , divu , rem , remu , md_sext_w} 
         = {`RV64IM_CORE_MULDIV_INFO{muldiv_req}} & i_alu_op_info[(`RV64IM_CORE_OP_INFO - 1) -: `RV64IM_CORE_MULDIV_INFO];
    wire [`RV64IM_CORE_DATA_WIDTH:0] mul_op1 = {(mulhu) ? 1'b0 :i_alu_rs1_data[63], i_alu_rs1_data};
    wire [`RV64IM_CORE_DATA_WIDTH:0] mul_op2 = {(mulhu|mulhsu) ? 1'b0 :i_alu_rs2_data[63], i_alu_rs2_data};
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] div_op1 = i_alu_rs1_data;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] div_op2 = i_alu_rs2_data;
    wire mul_op = mul | mulh | mulhsu | mulhu;
    wire div_op =  div | divu | rem | remu;
    wire div_ack;
    //wire mul_ack;
    //wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] mul_res;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] div_res;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] rem_res;

rv64im_core_div u_rv64im_core_div(
    .rs1           ( div_op1       ),
    .rs2           ( div_op2       ),
    .is_signed     ( (div | rem)   ),
    .i_alu_div_req ( div_op ),
    .i_stall       ( i_alu_stall   ),
    .div_res       ( div_res       ),
    .div_rem       ( rem_res       ),
    .o_alu_div_ack ( div_ack ),
    .clk           ( clk           ),
    .rstn          ( rstn & !i_alu_flush)
);
assign ex_ls_mul_op = mul_op;
rv64im_core_booth_mul u_rv64im_core_booth_mul(
    .rs1           ( mul_op1       ),
    .rs2           ( mul_op2       ),
    .i_alu_mul_req ( mul_op        ),
//    .mul_res       ( mul_res       ),
//    .o_alu_mul_ack ( mul_ack       ),
    .mul_cas_res1  ( ex_ls_mul_cas_res1),
    .mul_cas_res2  ( ex_ls_mul_cas_res2)
);

    //sys_info
    wire sys_req = i_alu_type_info[4];
    wire fence,fencei,ecall,ebreak,mret;
    assign {fence,fencei,ecall,ebreak,mret} 
    = {`RV64IM_CORE_SYS_INFO{sys_req}} & i_alu_op_info[(`RV64IM_CORE_OP_INFO - 1) -: `RV64IM_CORE_SYS_INFO];
    assign o_alu_intr_ecall = ecall;
    assign o_alu_intr_ebreak = ebreak;
    assign o_alu_intr_mret = mret;

    //csr_info
    wire csr_req = i_alu_type_info[5];
    wire csrrw , csrrs , csrrc , csrrwi , csrrsi , csrrci;
    assign {csrrw , csrrs , csrrc , csrrwi , csrrsi , csrrci} 
    = {`RV64IM_CORE_CSR_INFO{csr_req}} & i_alu_op_info[(`RV64IM_CORE_OP_INFO - 1) -: `RV64IM_CORE_CSR_INFO];
    wire [11:0] csr_raddr = i_alu_inst[31:20];
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] csr_op1 = i_alu_csr_rdata;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] csr_op2 = (csrrw | csrrs | csrrc) ? i_alu_rs1_data : {59'b0,i_alu_inst[19:15]};

//data path
    wire [63:0] addsub_op1 =  ({64{add_op | sub_op}}   & alu_op1);                                           
    wire [63:0] addsub_op2 =  ({64{add_op | sub_op}}   & alu_op2)
                            | ({64{res_imm}}           & i_alu_imm_data)
                            ; 
    wire [63:0] addsub_res =  addsub_op1 + (sub_op ? (~addsub_op2+1'b1) : addsub_op2);       

    wire [63:0] and_op1 = ({64{and_op}} & alu_op1);
    wire [63:0] and_op2 = ({64{and_op}} & alu_op2);
    wire [63:0] and_res = and_op1 & and_op2;
    
    wire [63:0] or_op1 = ({64{or_op}} & alu_op1);
    wire [63:0] or_op2 = ({64{or_op}} & alu_op2);
    wire [63:0] or_res = or_op1 | or_op2;
 
    wire [63:0] xor_op1 = ({64{xor_op}}  & alu_op1) 
                        | ({64{beq|bne}} & bjp_cmp_op1)
                        ;
    wire [63:0] xor_op2 = ({64{xor_op}}  & alu_op2) 
                        | ({64{beq|bne}} & bjp_cmp_op2)
                        ;
    wire [63:0] xor_res = xor_op1 ^ xor_op2;

    wire [63:0] sll_op1 = ({64{sll_op}} & alu_op1);
    wire [5 :0] sll_op2 = ({6{sll_op}}  & alu_op2[5:0]) & {~alu_sext_w,5'b11111};
    wire [63:0] sll_res = sll_op1 << sll_op2[5:0];

    wire [63:0] srl_op1 = ({64{srl_op}} & (alu_sext_w ? {32'b0,alu_op1[31:0]} : alu_op1));
    wire [5:0] srl_op2 = ({6{srl_op}} & alu_op2[5:0]) & {~alu_sext_w,5'b11111};    
    wire [63:0] srl_res = srl_op1 >> srl_op2;

    wire [63:0] sra_op1 = ({64{sra_op}} & (alu_sext_w ? {{32{alu_op1[31]}},alu_op1[31:0]} : alu_op1));
    wire [5:0] sra_op2 = ({6{sra_op}} & alu_op2[5:0]) & {~alu_sext_w,5'b11111};  
    wire [63:0] sra_res = ((64'hffffffffffffffff << (~sra_op2[5:0])) & {64{sra_op1[63]}}) | (sra_op1 >> sra_op2[5:0]);

    wire [63:0] slt_op1 = ({64{slt_op}}  & alu_op1)
                        | ({64{blt|bge}} & bjp_cmp_op1)
                        ;
    wire [63:0] slt_op2 = ({64{slt_op}}  & alu_op2)
                        | ({64{blt|bge}} & bjp_cmp_op2)
                        ;
    wire slt_cmp_res    = (slt_op1[63] == 1'b1 & slt_op2[63] == 1'b0) 
                        | ((slt_op1[63] == slt_op2[63]) &  (slt_op1[62:0] < slt_op2[62:0]))
                        ;
    wire [63:0] slt_res = {63'b0,slt_cmp_res};

    wire [63:0] sltu_op1 = ({64{sltu_op}}      & alu_op1)
                         | ({64{bltu | bgeu}}  & bjp_cmp_op1)
                         ;
    wire [63:0] sltu_op2 = ({64{sltu_op}}      & alu_op2)
                         | ({64{bltu | bgeu}}  & bjp_cmp_op2)
                         ;
    wire [63:0] sltu_res = {63'b0, (sltu_op1 < sltu_op2)};

//commit

//alu
    wire alu_to_rd_we = alu_req;
    wire [63:0] alu_res = (addsub_res | and_res | or_res | xor_res | sll_res | srl_res | sra_res | slt_res | sltu_res);
    wire [63:0] alu_to_rd_data = alu_sext_w ? {{32{alu_res[31]}}, alu_res[31:0]} : alu_res;

//bjp
    wire jump_res =  (beq  & ~(| xor_res))         //if rs1 = rs2  ,jump
                    |(bne  &  (| xor_res))         //if rs1 != rs2 ,jump
                    |(blt  &  slt_res[0] )         //if rs1 < rs2  ,jump
                    |(bge  & ~slt_res[0] )         //if rs1 >= rs2 ,jump
                    |(bltu &  sltu_res[0])     
                    |(bgeu & ~sltu_res[0]) 
                    ; 
    wire [63:0] bx_tgt  = bjp_op1 + bjp_op2;
`ifdef SAT_CNT  
    wire   cond_err = (bx_if_cond & (jump_res^if_bx_predict_pt));
    assign bx_if_cond = (beq | bne | blt | bge | bltu | bgeu);
    assign bx_if_pc = i_alu_pc;
    assign bx_if_pt = jump_res;
`ifdef RAS
    wire [`RV64IM_CORE_INST_WIDTH-1:0] inst = i_alu_inst;
    assign bx_if_push = ((inst[6:0] == 7'b1101111) | (inst[6:0] == 7'b1100111)&(inst[14:12]==3'b000)) & ((inst[11:7] == 5'd1) | (inst[11:7] == 5'd5)); //jal/jalr rd=x1/x5
    assign bx_if_pop  =  (inst[6:0] == 7'b1100111) & (inst[14:12]==3'b000) & ((inst[19:15] == 5'd1) | (inst[19:15] == 5'd5)) & (inst[19:15] != inst[11:7]);   //jalr rs1=x1/x5 rs1!=rd,
    wire jalr_err = ({bx_tgt[63:1],1'b0}!=idu_pc);
`endif
`endif

`ifdef SP                                 
    wire sp_nohit_err  = jump_res & ~i_alu_inst[31];
    wire sp_hit_err    = ~jump_res & i_alu_inst[31] & (beq | bne | blt | bge | bltu | bgeu);
    wire jump_flag = (jalr | sp_nohit_err | sp_hit_err);
`else
    wire jump_flag = (jal | jalr| jump_res);
`endif
    
    wire [63:0] pc_inc4 = i_alu_pc + 4;
    wire [2:0] jump_addr_sel;
    assign jump_addr_sel[0]=jalr;
    assign jump_addr_sel[1]=1'b0  //pred taken but real no taken
`ifdef SP                                 
                           | sp_hit_err 
`endif
`ifdef SAT_CNT                                 
                           | cond_err & if_bx_predict_pt 
`endif
                           ;
 
    wire [63:0] jump_addr = {64{jump_addr_sel[0]}}       & {bx_tgt[63:1],1'b0} 
                          | {64{jump_addr_sel[1]}}       & {pc_inc4}
                          | {64{!(|jump_addr_sel[1:0])}} & {bx_tgt}
                          ;


    wire bjp_to_rd_we = jal | jalr;
    wire [63:0] bjp_to_rd_data = bjp_to_rd_we ? pc_inc4 : 0;

//muldiv
    wire muldiv_to_rd_we = div_op & div_ack | mul_op;
    wire [63:0] muldiv_res =({`RV64IM_CORE_DATA_WIDTH{div|divu}} & div_res[63:0])
                         |  ({`RV64IM_CORE_DATA_WIDTH{rem|remu}} & rem_res[63:0])
                         ;
    wire [63:0] muldiv_to_rd_data = md_sext_w ? {{32{muldiv_res[31]}}, muldiv_res[31:0]} : muldiv_res;
    assign ex_ls_mul_mode = {(mulh|mulhsu|mulhu),md_sext_w};
//csr
    wire csr_to_rd_we = csr_req;
    wire [63:0] csr_to_rd_data = csr_op1;

//output
    //to reg
    wire [63:0] alu_rd_wdata = ({`RV64IM_CORE_DATA_WIDTH{alu_to_rd_we}}  & alu_to_rd_data)
                         |  ({`RV64IM_CORE_DATA_WIDTH{bjp_to_rd_we}}     & bjp_to_rd_data)
                         |  ({`RV64IM_CORE_DATA_WIDTH{muldiv_to_rd_we}}  & muldiv_to_rd_data)
                         |  ({`RV64IM_CORE_DATA_WIDTH{csr_to_rd_we}}     & csr_to_rd_data)
                         ;
    assign o_alu_rd_wen    = (alu_to_rd_we | bjp_to_rd_we | csr_to_rd_we| muldiv_to_rd_we | o_alu_mem_rw_ctrl) & (!i_alu_intr);//有异步中断发生时，wen;
    assign o_alu_rd_index = o_alu_rd_wen ? i_alu_rd_index : 0;

    assign o_alu_idu_wen   = o_alu_rd_wen;
    assign o_alu_idu_data  = alu_rd_wdata;
    assign o_alu_idu_index = o_alu_rd_index;
    assign o_alu_idu_load  = o_alu_mem_rw_ctrl | ex_ls_mul_op;

    //to lsu
    assign o_alu_mem_addr    = mem_op1 + mem_op2;
    assign o_alu_mem_rs2_data = i_alu_rs2_data;
    

    //to pipe_ctrl
    assign o_alu_stall = (div_op & !div_ack) | i_alu_addr_stall;
`ifdef SAT_CNT
    assign o_alu_flush =  cond_err
`ifdef RAS
                        | jalr & jalr_err
`else //RAS
                        | jalr
`endif //RAS
                        ;
`else //SATCNT
    assign o_alu_flush = jump_flag;    
`endif //SATCNT
    assign o_alu_flush_addr = jump_addr;

    //to csr
    assign o_alu_csr_wen = csr_req;
    assign o_alu_csr_addr = csr_raddr;
    assign o_alu_csr_wdata =({`RV64IM_CORE_DATA_WIDTH{csrrw|csrrwi}} & csr_op2)
                         |  ({`RV64IM_CORE_DATA_WIDTH{csrrs|csrrsi}} & csr_op1 | csr_op2)
                         |  ({`RV64IM_CORE_DATA_WIDTH{csrrc|csrrci}} & csr_op1 & (~csr_op2)) 
                         ;
    //to intr
    assign o_alu_intr_pc   = i_alu_pc;
    assign o_alu_intr_inst = i_alu_inst;
endmodule 
