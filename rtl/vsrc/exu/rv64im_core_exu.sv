`include "rv64im_core_defines.sv"

module rv64im_core_exu (
    input  wire [2:0] i_exu_intr_source,

    input  wire [`RV64IM_CORE_INST_WIDTH-1:0] i_exu_inst,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_exu_pc,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_exu_rs1_data,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_exu_rs2_data,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_exu_imm_data,
    input  wire [4:0] i_exu_rd_index,
    input  wire [`RV64IM_CORE_TYPE_INFO-1:0] i_exu_type_info,
    input  wire [`RV64IM_CORE_OP_INFO-1:0] i_exu_op_info,

    input wire i_exu_flush,              // 流水线冲刷标志
    input wire i_exu_stall,              // 流水线等待标志
    input wire i_exu_addr_stall,        
    //mem
    output wire o_exu_mem_rd_wen,
    output wire [4:0] o_exu_mem_rd_index,
    output wire o_exu_req,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_exu_addr,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_exu_rs2_data,
    output wire o_exu_rw_ctrl,
    output wire [4:0] o_exu_rw_len,

    output wire ex_ls_mul_op,
    output wire [1:0] ex_ls_mul_mode,  //{use hign 64bit, use low 32bit}
    output wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] ex_ls_mul_cas_res1,
    output wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] ex_ls_mul_cas_res2,
    //to idu
   output wire o_exu_idu_wen,
   output wire [4:0] o_exu_idu_index,
   output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_exu_idu_data,
   output wire o_exu_idu_load,

    //to pipe_ctrl
    output wire o_exu_alu_stall,         
    output wire o_exu_alu_flush,      
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_exu_alu_flush_addr,    //执行阶段冲刷地址

    output wire o_exu_intr_flush,      
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_exu_intr_flush_addr,    //执行阶段冲刷地址
`ifdef SAT_CNT  
    output wire bx_if_cond      ,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] bx_if_pc        ,
    output wire bx_if_pt        ,
    input  wire if_bx_predict_pt,
`ifdef RAS
    output wire bx_if_push,
    output wire bx_if_pop ,
`endif
`endif
    input  wire clk,
    input  wire rstn
);

`ifdef SAT_CNT
    wire wen = !(i_exu_stall);
    wire reset = !rstn | i_exu_flush;
    wire predict_pt;
    rv64im_core_reg #(1,0) reg_if_id_pc(clk,reset,if_bx_predict_pt,predict_pt,wen);
`endif

    wire [`RV64IM_CORE_INST_WIDTH-1:0] reg_alu_inst;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] reg_alu_pc;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] reg_alu_rs1_data;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] reg_alu_rs2_data;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] reg_alu_imm_data;
    wire [4:0] reg_alu_rd_index;
    wire [`RV64IM_CORE_TYPE_INFO-1:0] reg_alu_type_info;
    wire [`RV64IM_CORE_OP_INFO-1:0] reg_alu_op_info;

    wire alu_intr_ecall;
    wire alu_intr_ebreak;
    wire alu_intr_mret;
    wire [`RV64IM_CORE_INST_WIDTH-1:0] alu_intr_inst;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] alu_intr_pc;
    wire alu_intr;

    wire [2:0] cr_intr_req;
    wire cr_intr_wen;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] cr_intr_wmstatus;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] cr_intr_wmepc;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] cr_intr_wmcause;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] cr_intr_wmtval;

    wire [`RV64IM_CORE_DATA_WIDTH-1:0] cr_intr_rmstatus;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] cr_intr_rmtvec;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] cr_intr_rmepc;

    wire [`RV64IM_CORE_DATA_WIDTH-1:0] alu_csr_rdata;
    wire alu_csr_wen;
    wire [11:0] alu_csr_addr;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] alu_csr_wdata;


rv64im_core_id_alu u_rv64im_core_id_alu(
    .i_id_alu_inst      (i_exu_inst      ),
    .i_id_alu_pc        (i_exu_pc        ),
    .i_id_alu_rs1_data  (i_exu_rs1_data  ),
    .i_id_alu_rs2_data  (i_exu_rs2_data  ),
    .i_id_alu_imm_data  (i_exu_imm_data  ),
    .i_id_alu_rd_index  (i_exu_rd_index  ),
    .i_id_alu_type_info (i_exu_type_info ),
    .i_id_alu_op_info   (i_exu_op_info   ),
 
    .i_id_alu_flush     (i_exu_flush     ),
    .i_id_alu_stall     (i_exu_stall     ),
    .o_id_alu_inst      (reg_alu_inst      ),
    .o_id_alu_pc        (reg_alu_pc        ),
    .o_id_alu_rs1_data  (reg_alu_rs1_data  ),
    .o_id_alu_rs2_data  (reg_alu_rs2_data  ),
    .o_id_alu_imm_data  (reg_alu_imm_data  ),
    .o_id_alu_rd_index  (reg_alu_rd_index  ),
    .o_id_alu_type_info (reg_alu_type_info ),
    .o_id_alu_op_info   (reg_alu_op_info   ),
    .clk                (clk                ),
    .rstn               (rstn               )
);

rv64im_core_alu u_rv64im_core_alu(
    .i_alu_pc           (reg_alu_pc           ),
    .i_alu_inst         (reg_alu_inst         ),
    .i_alu_rs1_data     (reg_alu_rs1_data     ),
    .i_alu_rs2_data     (reg_alu_rs2_data     ),
    .i_alu_imm_data     (reg_alu_imm_data     ),
    .i_alu_rd_index     (reg_alu_rd_index     ),
    .i_alu_type_info    (reg_alu_type_info    ),
    .i_alu_op_info      (reg_alu_op_info      ),

    .i_alu_flush        (i_exu_flush          ),
    .i_alu_stall        (i_exu_stall          ),
    .i_alu_addr_stall   (i_exu_addr_stall     ),

    .o_alu_mem_req      (o_exu_req      ),
    .o_alu_mem_addr     (o_exu_addr     ),
    .o_alu_mem_rs2_data (o_exu_rs2_data ),
    .o_alu_mem_rw_ctrl  (o_exu_rw_ctrl  ),
    .o_alu_mem_rw_len   (o_exu_rw_len   ),

    .ex_ls_mul_op       (ex_ls_mul_op),
    .ex_ls_mul_mode     (ex_ls_mul_mode),
    .ex_ls_mul_cas_res1 (ex_ls_mul_cas_res1),
    .ex_ls_mul_cas_res2 (ex_ls_mul_cas_res2),

    .o_alu_rd_index     (o_exu_mem_rd_index),
    .o_alu_rd_wen       (o_exu_mem_rd_wen  ),

    .o_alu_stall        (o_exu_alu_stall        ),
    .o_alu_flush        (o_exu_alu_flush        ),
    .o_alu_flush_addr   (o_exu_alu_flush_addr   ),

    .o_alu_idu_wen      (o_exu_idu_wen      ),
    .o_alu_idu_index    (o_exu_idu_index    ),
    .o_alu_idu_data     (o_exu_idu_data     ),
    .o_alu_idu_load     (o_exu_idu_load     ),
    .i_alu_intr         (alu_intr          ),
    .o_alu_intr_ecall   (alu_intr_ecall    ),
    .o_alu_intr_ebreak  (alu_intr_ebreak      ),    
    .o_alu_intr_mret    (alu_intr_mret    ),
    .o_alu_intr_inst    (alu_intr_inst    ),
    .o_alu_intr_pc      (alu_intr_pc      ),

    .i_alu_csr_rdata    (alu_csr_rdata    ),
    .o_alu_csr_wen      (alu_csr_wen      ),
    .o_alu_csr_addr     (alu_csr_addr     ),
    .o_alu_csr_wdata    (alu_csr_wdata    ),
`ifdef SAT_CNT  
    .bx_if_cond         (bx_if_cond       ),
    .bx_if_pc           (bx_if_pc         ),
    .bx_if_pt           (bx_if_pt         ),
    .if_bx_predict_pt   (predict_pt       ),
`ifdef RAS
    .idu_pc             (i_exu_pc         ),
    .bx_if_push         (bx_if_push       ),
    .bx_if_pop          (bx_if_pop        ),
`endif
`endif    
    .clk                (clk                ),
    .rstn               (rstn               )
);


rv64im_core_csr_reg u_rv64im_core_csr_reg(
    .i_cr_intr_source  (i_exu_intr_source    ),
    .o_cr_intr_req     (cr_intr_req          ),    
    .i_cr_wdata        (alu_csr_wdata        ),
    .i_cr_wen          (alu_csr_wen          ),
    .i_cr_addr         (alu_csr_addr         ),
    .o_cr_rdata        (alu_csr_rdata        ),
    .i_cr_intr_wen     (cr_intr_wen     ),
    .i_cr_intr_mstatus (cr_intr_wmstatus ),
    .i_cr_intr_mepc    (cr_intr_wmepc    ),
    .i_cr_intr_mcause  (cr_intr_wmcause  ),
    .i_cr_intr_mtval   (cr_intr_wmtval   ),
    .o_cr_intr_mstatus (cr_intr_rmstatus ),
    .o_cr_intr_mtvec   (cr_intr_rmtvec   ),
    .o_cr_intr_mepc    (cr_intr_rmepc    ),
    .clk               (clk               ),
    .rstn              (rstn              )
);

rv64im_core_intr_ctrl u_rv64im_core_intr_ctrl(
    .i_intr_req        (cr_intr_req         ),
    .i_intr_ecall      (alu_intr_ecall      ),
    .i_intr_ebreak     (alu_intr_ebreak     ),
    .i_intr_mret       (alu_intr_mret       ),
    .i_intr_pc         (alu_intr_pc         ),
    .i_intr_inst       (alu_intr_inst       ),
    .o_intr_alu_intr   (alu_intr            ),

    .i_intr_mtvec      (cr_intr_rmtvec      ),
    .i_intr_mepc       (cr_intr_rmepc       ),
    .i_intr_mstatus    (cr_intr_rmstatus    ),
    
    .o_intr_csr_wen    (cr_intr_wen    ),
    .o_intr_mepc       (cr_intr_wmepc       ),
    .o_intr_mstatus    (cr_intr_wmstatus    ),
    .o_intr_mcause     (cr_intr_wmcause     ),
    .o_intr_mtval      (cr_intr_wmtval      ),

    .o_intr_flush_en   (o_exu_intr_flush   ),
    .o_intr_flush_addr (o_exu_intr_flush_addr )
);


endmodule //exu
