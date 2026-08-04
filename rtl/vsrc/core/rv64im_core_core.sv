`include "rv64im_core_defines.sv"

module rv64im_core_core (
    //pc
    output wire o_ifu_req_vld,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_ifu_addr,
    input  wire i_ifu_req_rdy,

    input  wire i_ifu_rsp_vld,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_ifu_rdata,
    output wire o_ifu_rsp_rdy,

    //mem
    output wire o_lsu_req_vld,
    output wire o_lsu_wen,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_lsu_addr,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_lsu_wdata,
    output wire [ 7:0] o_lsu_wmask,
    input  wire i_lsu_req_rdy,

    input  wire i_lsu_rsp_vld,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_lsu_rdata,
    output wire o_lsu_rsp_rdy,

    //intr
    input  wire [2:0] i_core_intr,
    input  wire clk,
    input  wire rstn
);
//ifu
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] pipe_ifu_flush_addr;
    wire [4:0] pipec_flush;
    wire [4:0] pipec_satll;

    wire pipe_ifu_flush = pipec_flush[0];
    wire pipe_idu_stall = pipec_satll[1];
    wire pipe_exu_stall = pipec_satll[2];
    wire pipe_mem_stall = pipec_satll[3];
    wire pipe_wbu_stall = pipec_satll[4];

    wire pipe_ifu_stall = pipec_satll[0];
    wire pipe_idu_flush = pipec_flush[1];
    wire pipe_exu_flush = pipec_flush[2];
    wire pipe_mem_flush = pipec_flush[3];
    wire pipe_wbu_flush = pipec_flush[4];

    wire ifu_idu_vld;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] ifu_idu_pc;
    wire [`RV64IM_CORE_INST_WIDTH-1:0] ifu_idu_inst;
//idu
    wire wbu_idu_rd_wen;
    wire [4:0] wbu_idu_rd_index;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] wbu_idu_rd_data;

    wire exu_idu_exu_load;
    wire exu_idu_exu_rd_wen;
    wire [4:0] exu_idu_exu_rd_index;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] exu_idu_exu_rd_data;
    wire mem_idu_mem_rd_wen;
    wire [4:0] mem_idu_mem_rd_index;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mem_idu_mem_rd_data;
    wire idu_exu_id_flush_ex;
    wire idu_pipe_stall;

    wire [`RV64IM_CORE_INST_WIDTH-1:0] idu_exu_inst;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] idu_exu_pc;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] idu_exu_rs1_data;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] idu_exu_rs2_data;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] idu_exu_imm_data;
    wire [4:0] idu_exu_rd_index;

    wire [`RV64IM_CORE_TYPE_INFO-1:0] idu_exu_type_info;
    wire [`RV64IM_CORE_OP_INFO-1:0] idu_exu_op_info;
//exu
    wire exu_mem_rd_wen;
    wire [4:0] exu_mem_rd_index;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] exu_mem_rd_data = exu_idu_exu_rd_data;
    wire exu_mem_req;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] exu_mem_addr;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] exu_mem_rs2_data;
    wire exu_mem_rw_ctrl;
    wire [4:0] exu_mem_rw_len;

    wire ex_ls_mul_op;
    wire [1:0] ex_ls_mul_mode;  //{use hign 64bit, use low 32bit}
    wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] ex_ls_mul_cas_res1;
    wire [2*`RV64IM_CORE_DATA_WIDTH-1:0] ex_ls_mul_cas_res2;

    wire exu_pipe_alu_stall;         
    wire exu_pipe_alu_flush;      
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] exu_pipe_alu_flush_addr;    //执行阶段冲刷地址

    wire exu_pipe_intr_flush;      
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] exu_pipe_intr_flush_addr;    //执行阶段冲刷地址
//memu
    wire mem_pipe_stall;
    wire mem_addr_stall;
    wire [4:0] mem_wbu_rd_index;
    wire mem_wbu_rd_wen;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] mem_wbu_memtord_data;
//wbu
`ifdef SAT_CNT  
    wire bx_if_cond       ;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] bx_if_pc;
    wire bx_if_pt         ;
    wire if_id_predict_pt ;
    wire id_bx_predict_pt ;
`ifdef RAS
    wire bx_if_push;
    wire bx_if_pop;
`endif
`endif

rv64im_core_ifu u_rv64im_core_ifu(
    .i_if_rdata      ( i_ifu_rdata      ),
    .o_if_addr       ( o_ifu_addr       ),
    .i_if_req_rdy   ( i_ifu_req_rdy   ),
    .o_if_req_vld   ( o_ifu_req_vld   ),
    .o_if_rsp_rdy   ( o_ifu_rsp_rdy   ),
    .i_if_rsp_vld   ( i_ifu_rsp_vld   ),

    .i_if_flush_addr (pipe_ifu_flush_addr ),
    .i_if_flush      (pipe_ifu_flush      ),
    .i_if_stall      (pipe_ifu_stall      ),

    .o_if_vld        (ifu_idu_vld         ),
    .o_if_pc         (ifu_idu_pc         ),
    .o_if_inst       (ifu_idu_inst       ),
`ifdef SAT_CNT  
    .i_if_bx_cond    (bx_if_cond       ),
    .i_if_bx_pc      (bx_if_pc         ),
    .i_if_bx_pt      (bx_if_pt         ),
    .o_if_predict_pt (if_id_predict_pt ),
`ifdef RAS
    .i_if_bx_push    (bx_if_push       ),
    .i_if_bx_pop     (bx_if_pop        ),
`endif
`endif
    .clk             ( clk             ),
    .rstn            ( rstn            )
);
wire wbu_idu_stall = pipe_wbu_stall;
rv64im_core_idu u_rv64im_core_idu(
    .i_idu_if_vld       (ifu_idu_vld         ),
    .i_idu_inst         (ifu_idu_inst         ),
    .i_idu_pc           (ifu_idu_pc           ),
    
    .i_idu_stall        (pipe_idu_stall        ),
    .i_idu_flush        (pipe_idu_flush        ),

    .i_idu_wb_stall     (wbu_idu_stall        ),
    .i_idu_rd_index     (wbu_idu_rd_index     ),
    .i_idu_rd_wen       (wbu_idu_rd_wen       ),
    .i_idu_rd_data      (wbu_idu_rd_data      ),
    .i_idu_exu_load     (exu_idu_exu_load     ),
    .i_idu_exu_rd_wen   (exu_idu_exu_rd_wen   ),
    .i_idu_exu_rd_index (exu_idu_exu_rd_index ),
    .i_idu_exu_rd_data  (exu_idu_exu_rd_data  ),
    .i_idu_mem_rd_wen   (mem_idu_mem_rd_wen   ),
    .i_idu_mem_rd_index (mem_idu_mem_rd_index ),
    .i_idu_mem_rd_data  (mem_idu_mem_rd_data  ),

    .o_idu_id_flush_ex  (idu_pipe_stall       ),
    .o_idu_inst         (idu_exu_inst         ),
    .o_idu_pc           (idu_exu_pc           ),
    .o_idu_rs1_data     (idu_exu_rs1_data     ),
    .o_idu_rs2_data     (idu_exu_rs2_data     ),
    .o_idu_imm_data     (idu_exu_imm_data     ),
    .o_idu_rd_index     (idu_exu_rd_index     ),
    .o_idu_type_info    (idu_exu_type_info    ),
    .o_idu_op_info      (idu_exu_op_info      ),
`ifdef SAT_CNT  
    .if_id_predict_pt   (if_id_predict_pt     ),
    .id_bx_predict_pt   (id_bx_predict_pt     ),
`endif
    .clk                (clk                ),
    .rstn               (rstn               )
);

rv64im_core_exu u_rv64im_core_exu(
    .i_exu_intr_source     (i_core_intr     ),

    .i_exu_inst            (idu_exu_inst            ),
    .i_exu_pc              (idu_exu_pc              ),
    .i_exu_rs1_data        (idu_exu_rs1_data        ),
    .i_exu_rs2_data        (idu_exu_rs2_data        ),
    .i_exu_imm_data        (idu_exu_imm_data        ),
    .i_exu_rd_index        (idu_exu_rd_index        ),
    .i_exu_type_info       (idu_exu_type_info       ),
    .i_exu_op_info         (idu_exu_op_info         ),

    .i_exu_flush           (pipe_exu_flush           ),
    .i_exu_stall           (pipe_exu_stall           ),
    .i_exu_addr_stall      (mem_addr_stall           ),

    .o_exu_mem_rd_wen      (exu_mem_rd_wen      ),
    .o_exu_mem_rd_index    (exu_mem_rd_index    ),
    .o_exu_req             (exu_mem_req             ),
    .o_exu_addr            (exu_mem_addr            ),
    .o_exu_rs2_data        (exu_mem_rs2_data        ),
    .o_exu_rw_ctrl         (exu_mem_rw_ctrl         ),
    .o_exu_rw_len          (exu_mem_rw_len          ),

    .ex_ls_mul_op          (ex_ls_mul_op),
    .ex_ls_mul_mode        (ex_ls_mul_mode),
    .ex_ls_mul_cas_res1    (ex_ls_mul_cas_res1),
    .ex_ls_mul_cas_res2    (ex_ls_mul_cas_res2),

    .o_exu_idu_wen         (exu_idu_exu_rd_wen    ),
    .o_exu_idu_index       (exu_idu_exu_rd_index    ),
    .o_exu_idu_data        (exu_idu_exu_rd_data     ),
    .o_exu_idu_load        (exu_idu_exu_load        ),

    .o_exu_alu_stall       (exu_pipe_alu_stall       ),
    .o_exu_alu_flush       (exu_pipe_alu_flush       ),
    .o_exu_alu_flush_addr  (exu_pipe_alu_flush_addr  ),
    
    .o_exu_intr_flush      (exu_pipe_intr_flush      ),
    .o_exu_intr_flush_addr (exu_pipe_intr_flush_addr ),
`ifdef SAT_CNT  
    .bx_if_cond            (bx_if_cond       ),
    .bx_if_pc              (bx_if_pc         ),
    .bx_if_pt              (bx_if_pt         ),
    .if_bx_predict_pt      (id_bx_predict_pt ),
`ifdef RAS
    .bx_if_push            (bx_if_push       ),
    .bx_if_pop             (bx_if_pop        ),
`endif
`endif
    .clk                   (clk                   ),
    .rstn                  (rstn                  )
);


rv64im_core_lsu u_rv64im_core_lsu(
    .i_lsu_rd_index     (exu_mem_rd_index     ),
    .i_lsu_rd_wen       (exu_mem_rd_wen      ),
    .i_lsu_rd_data      (exu_mem_rd_data      ),
    .i_lsu_req          (exu_mem_req          ),
    .i_lsu_addr         (exu_mem_addr         ),
    .i_lsu_rs2_data     (exu_mem_rs2_data     ),
    .i_lsu_rw_ctrl      (exu_mem_rw_ctrl      ),
    .i_lsu_rw_len       (exu_mem_rw_len       ),

    .ex_ls_mul_op       (ex_ls_mul_op),
    .ex_ls_mul_mode     (ex_ls_mul_mode),
    .ex_ls_mul_cas_res1 (ex_ls_mul_cas_res1),
    .ex_ls_mul_cas_res2 (ex_ls_mul_cas_res2),

    .i_lsu_flush        (pipe_mem_flush        ),
    .i_lsu_stall        (pipe_mem_stall        ),

    .o_lsu_stall        (mem_pipe_stall        ),
    .o_lsu_addr_stall   (mem_addr_stall        ),

    .o_lsu_rd_index     (mem_wbu_rd_index     ),
    .o_lsu_rd_wen       (mem_wbu_rd_wen       ),
    .o_lsu_memtord_data (mem_wbu_memtord_data ),

    .o_lsu_idu_wen      (mem_idu_mem_rd_wen      ),
    .o_lsu_idu_index    (mem_idu_mem_rd_index    ),
    .o_lsu_idu_data     (mem_idu_mem_rd_data     ),

    .o_lsu_req_vld     ( o_lsu_req_vld     ),
    .o_lsu_wen          ( o_lsu_wen          ),
    .o_lsu_addr         ( o_lsu_addr         ),
    .o_lsu_wdata        ( o_lsu_wdata        ),
    .o_lsu_wmask        ( o_lsu_wmask        ),
    .i_lsu_req_rdy     ( i_lsu_req_rdy     ),
    .i_lsu_rsp_vld     ( i_lsu_rsp_vld     ),
    .i_lsu_rdata        ( i_lsu_rdata        ),
    .o_lsu_rsp_rdy     ( o_lsu_rsp_rdy     ),

    .clk                 (clk                   ),
    .rstn                (rstn                  )
);




rv64im_core_wbu u_rv64im_core_wbu(
    .i_wbu_rd_index     (mem_wbu_rd_index     ),
    .i_wbu_rd_wen       (mem_wbu_rd_wen       ),
    .i_wbu_memtord_data (mem_wbu_memtord_data ),
    .i_wbu_flush        (pipe_wbu_flush        ),
    .i_wbu_stall        (pipe_wbu_stall        ),
    .o_wbu_rd_index     (wbu_idu_rd_index     ),
    .o_wbu_rd_wen       (wbu_idu_rd_wen       ),
    .o_wbu_rd_data      (wbu_idu_rd_data      ),
    .clk                (clk                ),
    .rstn               (rstn               )
);

rv64im_core_pipe_ctrl u_rv64im_core_pipe_ctrl(
    .i_pipec_exu_stall       (exu_pipe_alu_stall       ),
    .i_pipec_exu_flush       (exu_pipe_alu_flush       ),
    .i_pipec_exu_flush_addr  (exu_pipe_alu_flush_addr  ),
    .i_pipec_mem_stall       (mem_pipe_stall           ),
    .i_pipec_idu_stall       (idu_pipe_stall           ),
    .i_pipec_intr_flush      (exu_pipe_intr_flush       ),
    .i_pipec_intr_flush_addr (exu_pipe_intr_flush_addr  ),
    .o_pipec_stall           (pipec_satll               ),
    .o_pipec_flush           (pipec_flush               ),
    .o_pipec_flush_addr      (pipe_ifu_flush_addr      )
);


endmodule
