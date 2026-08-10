module rv64im_core_top # (
    parameter RW_DATA_WIDTH     = 64,
    parameter RW_ADDR_WIDTH     = 32,
    parameter AXI_DATA_WIDTH    = 64,
    parameter AXI_ADDR_WIDTH    = 32,
    parameter AXI_ID_WIDTH      = 4,
    parameter AXI_STRB_WIDTH    = AXI_DATA_WIDTH/8,
    parameter AXI_USER_WIDTH    = 1,
    parameter ICACHE_SIZE       = 8192,
    parameter DCACHE_SIZE       = 8192
)(
   // Advanced eXtensible Interface
    input                               axi_aw_ready_i,              
    output                              axi_aw_valid_o,
    output [AXI_ADDR_WIDTH-1:0]         axi_aw_addr_o,
    output [2:0]                        axi_aw_prot_o,
    output [AXI_ID_WIDTH-1:0]           axi_aw_id_o,
    output [AXI_USER_WIDTH-1:0]         axi_aw_user_o,
    output [7:0]                        axi_aw_len_o,
    output [2:0]                        axi_aw_size_o,
    output [1:0]                        axi_aw_burst_o,
    output                              axi_aw_lock_o,
    output [3:0]                        axi_aw_cache_o,
    output [3:0]                        axi_aw_qos_o,
    output [3:0]                        axi_aw_region_o,

    input                               axi_w_ready_i,                
    output                              axi_w_valid_o,
    output [AXI_DATA_WIDTH-1:0]         axi_w_data_o,
    output [AXI_DATA_WIDTH/8-1:0]       axi_w_strb_o,
    output                              axi_w_last_o,
    output [AXI_USER_WIDTH-1:0]         axi_w_user_o,
    
    output                              axi_b_ready_o,                
    input                               axi_b_valid_i,
    input  [1:0]                        axi_b_resp_i,                 
    input  [AXI_ID_WIDTH-1:0]           axi_b_id_i,
    input  [AXI_USER_WIDTH-1:0]         axi_b_user_i,

    input                               axi_ar_ready_i,                
    output                              axi_ar_valid_o,
    output [AXI_ADDR_WIDTH-1:0]         axi_ar_addr_o,
    output [2:0]                        axi_ar_prot_o,
    output [AXI_ID_WIDTH-1:0]           axi_ar_id_o,
    output [AXI_USER_WIDTH-1:0]         axi_ar_user_o,
    output [7:0]                        axi_ar_len_o,
    output [2:0]                        axi_ar_size_o,
    output [1:0]                        axi_ar_burst_o,
    output                              axi_ar_lock_o,
    output [3:0]                        axi_ar_cache_o,
    output [3:0]                        axi_ar_qos_o,
    output [3:0]                        axi_ar_region_o,
    
    output                              axi_r_ready_o,                 
    input                               axi_r_valid_i, 
  
    input  [1:0]                        axi_r_resp_i,
    input  [AXI_DATA_WIDTH-1:0]         axi_r_data_i,
    input                               axi_r_last_i,
    input  [AXI_ID_WIDTH-1:0]           axi_r_id_i,
    input  [AXI_USER_WIDTH-1:0]         axi_r_user_i,

    input wire clk,
    input wire rstn

);

    wire ifu_req_vld   ; 
    wire [64-1:0] ifu_addr       ; 
    wire ifu_req_rdy   ; 
    wire ifu_rsp_vld   ; 
    wire [RW_DATA_WIDTH-1:0] ifu_rdata      ; 
    wire ifu_rsp_rdy   ; 

/*
    lsu
*/
     wire lsu_req_vld; 
     wire lsu_req_rdy; 
     wire lsu_wen     ; 
     wire [64-1:0] lsu_addr    ; 
     wire [RW_DATA_WIDTH-1:0] lsu_wdata   ; 
     wire [7:0] lsu_wmask   ;
    wire lsu_rsp_vld;
    wire lsu_rsp_rdy;
     wire [RW_DATA_WIDTH-1:0] lsu_rdata   ; 

///===addr decode start===///
//lsu => a0(mem) + a1
//a1  => b0(clt) + b1

//b1_t + a0_t => m1
//icache      => m0
    parameter NS=3;

    wire [NS-1:0] cs; 
    
    wire [NS-1:0] s_req_vld;
    wire [NS-1:0] s_wen;
    wire [RW_ADDR_WIDTH-1:0] s_addr [NS-1:0];
    wire [RW_DATA_WIDTH-1:0] s_wdata [NS-1:0];
    wire [ 7:0] s_wmask [NS-1:0];
    wire [NS-1:0] s_req_rdy;

    wire [NS-1:0] s_rsp_vld;
    wire [RW_DATA_WIDTH-1:0] s_rdata [NS-1:0];
    wire [NS-1:0] s_rsp_rdy;

    assign cs[0] = (lsu_addr[31:28] == 4'h8);
    assign cs[1] = (lsu_addr[31:28] == 4'h2);
    assign cs[2] = (lsu_addr[31:28] != 4'h2) & (lsu_addr[31:28] != 4'h8);

rv64im_core_1toN#(
    .RW_DATA_WIDTH ( 64 ),
    .NS            ( 3 ),
    .RW_ADDR_WIDTH ( 32 )
)u_rv64im_core_1toN(
    .i_cs          ( cs          ),
    .i_m0_req_vld ( lsu_req_vld ),
    .i_m0_wen      ( lsu_wen      ),
    .i_m0_addr     ( lsu_addr[31:0]   ),
    .i_m0_wdata    ( lsu_wdata    ),
    .i_m0_wmask    ( lsu_wmask    ),
    .o_m0_req_rdy ( lsu_req_rdy ),
    .i_m0_rsp_rdy ( lsu_rsp_rdy ),
    .o_m0_rdata    ( lsu_rdata    ),
    .o_m0_rsp_vld ( lsu_rsp_vld ),
    
    .o_req_vld    ( s_req_vld    ),
    .o_wen         ( s_wen         ),
    .o_addr        ( s_addr     ),
    .o_wdata       ( s_wdata    ),
    .o_wmask       ( s_wmask    ),
    .i_req_rdy    ( s_req_rdy    ),
    .i_rsp_vld    ( s_rsp_vld    ),
    .i_rdata       ( s_rdata       ),
    .o_rsp_rdy    ( s_rsp_rdy    ),
    .clk            ( clk            ),
    .rstn           ( rstn           )
);

    wire m0_vld;
    wire m0_wen;
    wire [RW_ADDR_WIDTH-1:0] m0_addr;
    wire [RW_DATA_WIDTH-1:0] m0_wdata;
    wire [7:0] m0_wmask;
    wire m0_rdy;
    wire [RW_DATA_WIDTH-1:0] m0_rdata;
 
    wire m1_vld;
    wire m1_wen;
    wire [RW_ADDR_WIDTH-1:0] m1_addr;
    wire [RW_DATA_WIDTH-1:0] m1_wdata;
    wire [7:0] m1_wmask;
    wire m1_rdy;
    wire [RW_DATA_WIDTH-1:0] m1_rdata;

    wire m2_vld;
    wire m2_wen;
    wire [RW_ADDR_WIDTH-1:0] m2_addr;
    wire [RW_DATA_WIDTH-1:0] m2_wdata;
    wire [7:0] m2_wmask;
    wire m2_rdy;
    wire [RW_DATA_WIDTH-1:0] m2_rdata;

    wire m3_vld;
    wire m3_wen;
    wire [RW_ADDR_WIDTH-1:0] m3_addr;
    wire [RW_DATA_WIDTH-1:0] m3_wdata;
    wire [7:0] m3_wmask;
    wire m3_rdy;
    wire [RW_DATA_WIDTH-1:0] m3_rdata;

rv64im_core_AtoB#(
    .RW_DATA_WIDTH ( 64 ),
    .RW_ADDR_WIDTH ( 32 )
)u_rv64im_core_AtoB(
    .i_m0_req_vld ( s_req_vld[2] ),
    .i_m0_wen      ( s_wen[2]      ),
    .i_m0_addr     ( s_addr[2][31:0]     ),
    .i_m0_wdata    ( s_wdata[2]    ),
    .i_m0_wmask    ( s_wmask[2]    ),
    .o_m0_req_rdy ( s_req_rdy[2] ),
    .i_m0_rsp_rdy ( s_rsp_rdy[2] ),
    .o_m0_rdata    ( s_rdata[2]    ),
    .o_m0_rsp_vld ( s_rsp_vld[2] ),

    .o_abr_valid   ( m2_vld   ),
    .o_abr_wen     ( m2_wen     ),
    .o_abr_addr    ( m2_addr    ),
    .o_abr_wdata   ( m2_wdata   ),
    .o_abr_wmask   ( m2_wmask   ),
    .i_abr_rdata   ( m2_rdata   ),
    .i_abr_ready   ( m2_rdy   ),
    .clk           ( clk           ),
    .rstn          ( rstn          )
);

rv64im_core_2to1#(
    .RW_DATA_WIDTH ( 64 ),
    .RW_ADDR_WIDTH ( 32 )
)u_rv64im_core_2to1(
    .i_m0_valid    ( m2_vld    ),
    .i_m0_wen      ( m2_wen      ),
    .i_m0_addr     ( m2_addr     ),
    .i_m0_wdata    ( m2_wdata    ),
    .i_m0_wmask    ( m2_wmask    ),
    .o_m0_rdata    ( m2_rdata    ),
    .o_m0_ready    ( m2_rdy    ),

    .i_m1_valid    ( m1_vld    ),
    .i_m1_wen      ( m1_wen      ),
    .i_m1_addr     ( m1_addr     ),
    .i_m1_wdata    ( m1_wdata    ),
    .i_m1_wmask    ( m1_wmask    ),
    .o_m1_rdata    ( m1_rdata    ),
    .o_m1_ready    ( m1_rdy    ),

    .o_abr_valid   ( m3_vld   ),
    .o_abr_wen     ( m3_wen     ),
    .o_abr_addr    ( m3_addr    ),
    .o_abr_wdata   ( m3_wdata   ),
    .o_abr_wmask   ( m3_wmask   ),
    .i_abr_rdata   ( m3_rdata   ),
    .i_abr_ready   ( m3_rdy   )
);

///===addr decode end===///
     
/*
    arbiter；
*/

    wire clt_msip;
    wire clt_mtip;
    wire [2:0] core_intr = {1'b0,clt_msip,clt_mtip};//2:外部中断 //1:软件中断 //0:计时器中断

rv64im_core_core u_rv64im_core_core(
    .o_ifu_req_vld    ( ifu_req_vld    ),
    .o_ifu_addr        ( ifu_addr        ),
    .i_ifu_req_rdy    ( ifu_req_rdy    ),
    .i_ifu_rsp_vld    ( ifu_rsp_vld    ),
    .i_ifu_rdata       ( ifu_rdata       ),
    .o_ifu_rsp_rdy    ( ifu_rsp_rdy    ),

    .o_lsu_req_vld    ( lsu_req_vld    ),
    .o_lsu_wen         ( lsu_wen         ),
    .o_lsu_addr        ( lsu_addr        ),
    .o_lsu_wdata       ( lsu_wdata       ),
    .o_lsu_wmask       ( lsu_wmask       ),
    .i_lsu_req_rdy    ( lsu_req_rdy    ),
    .i_lsu_rsp_vld    ( lsu_rsp_vld    ),
    .i_lsu_rdata       ( lsu_rdata       ),
    .o_lsu_rsp_rdy    ( lsu_rsp_rdy    ),

    .i_core_intr       ( core_intr       ),

    .clk               ( clk             ),
    .rstn              ( rstn            )
);

rv64im_core_clint u_rv64im_core_clint(
    .i_clt_req_vld ( s_req_vld[1] ),
    .i_clt_wen      ( s_wen[1]      ),
    .i_clt_addr     ( {32'b0, s_addr[1]}),
    .i_clt_wdata    ( s_wdata[1]    ),
    .i_clt_wmask    ( s_wmask[1]    ),
    .o_clt_req_rdy ( s_req_rdy[1] ),

    .i_clt_rsp_rdy ( s_rsp_rdy[1] ),
    .o_clt_rdata    ( s_rdata[1]    ),
    .o_clt_rsp_vld ( s_rsp_vld[1] ),

    .o_clt_msip     ( clt_msip     ),
    .o_clt_mtip     ( clt_mtip     ),

    .clk            ( clk          ),
    .rstn           ( rstn         )
);

rv64im_core_dcache#(
    .CACHE_SIZE     ( DCACHE_SIZE ),
    .LINE_SIZE      ( 256  ),
    .RW_DATA_WIDTH  ( 64   ),
    .RW_ADDR_WIDTH  ( 32   )
)u_rv64im_core_dcache(
    .i_mem_req_vld ( s_req_vld[0] ),
    .i_mem_wen      ( s_wen[0]      ),
    .i_mem_addr     ( s_addr[0][31:0]),
    .i_mem_wdata    ( s_wdata[0]    ),
    .i_mem_wmask    ( s_wmask[0]    ),
    .o_mem_req_rdy ( s_req_rdy[0] ),
    .i_mem_rsp_rdy ( s_rsp_rdy[0] ),
    .o_mem_rdata    ( s_rdata[0]    ),
    .o_mem_rsp_vld ( s_rsp_vld[0] ),

    .o_abr_valid    ( m1_vld      ),
    .o_abr_wen      ( m1_wen      ),
    .o_abr_addr     ( m1_addr     ),
    .o_abr_wdata    ( m1_wdata    ),
    .o_abr_wmask    ( m1_wmask    ),
    .i_abr_rdata    ( m1_rdata    ),
    .i_abr_ready    ( m1_rdy      ),

    .clk            ( clk            ),
    .rstn           ( rstn           )
);

rv64im_core_dcache#(
    .CACHE_SIZE     ( ICACHE_SIZE ),
    .LINE_SIZE      ( 256  ),
    .RW_DATA_WIDTH  ( 64   ),
    .RW_ADDR_WIDTH  ( 32   )
)u_rv64im_core_icache(
    .i_mem_req_vld ( ifu_req_vld ),
    .i_mem_wen      ( 1'b0  ),
    .i_mem_wdata    ( 64'b0  ),
    .i_mem_wmask    ( 8'b0  ),
    .i_mem_addr     ( ifu_addr[31:0]),
    .o_mem_req_rdy ( ifu_req_rdy ),
    .i_mem_rsp_rdy ( ifu_rsp_rdy ),
    .o_mem_rdata    ( ifu_rdata    ),
    .o_mem_rsp_vld ( ifu_rsp_vld ),

    .o_abr_valid    ( m0_vld      ),
    .o_abr_wen      ( m0_wen      ),
    .o_abr_addr     ( m0_addr     ),
    .o_abr_wdata    ( m0_wdata    ),
    .o_abr_wmask    ( m0_wmask    ),
    .i_abr_rdata    ( m0_rdata    ),
    .i_abr_ready    ( m0_rdy      ),
    
    .clk            ( clk            ),
    .rstn           ( rstn           )
);


rv64im_core_axi_rw#(
    .RW_DATA_WIDTH   ( 64 ),
    .RW_ADDR_WIDTH   ( 32 ),
    .AXI_DATA_WIDTH  ( 64 ),
    .AXI_ADDR_WIDTH  ( 32 ),
    .AXI_ID_WIDTH    ( 4 ),
    .AXI_STRB_WIDTH  ( AXI_DATA_WIDTH/8 ),
    .AXI_USER_WIDTH  ( 1 )
)u_rv64im_core_axi_rw(
    .clk             ( clk             ),
    .rstn            ( rstn            ),

    .i_m0_vld        ( m0_vld      ),
    .i_m0_wen        ( m0_wen      ),
    .i_m0_addr       ( m0_addr     ),
    .i_m0_wdata      ( m0_wdata    ),
    .i_m0_wmask      ( m0_wmask    ),
    .o_m0_rdata      ( m0_rdata    ),
    .o_m0_rdy        ( m0_rdy      ),

    .i_m1_vld        ( m3_vld      ),
    .i_m1_wen        ( m3_wen      ),
    .i_m1_addr       ( m3_addr     ),
    .i_m1_wdata      ( m3_wdata    ),
    .i_m1_wmask      ( m3_wmask    ),
    .o_m1_rdata      ( m3_rdata    ),
    .o_m1_rdy        ( m3_rdy      ),

    .axi_aw_ready_i  ( axi_aw_ready_i  ),
    .axi_aw_valid_o  ( axi_aw_valid_o  ),
    .axi_aw_addr_o   ( axi_aw_addr_o   ),
    .axi_aw_prot_o   ( axi_aw_prot_o   ),
    .axi_aw_id_o     ( axi_aw_id_o     ),
    .axi_aw_user_o   ( axi_aw_user_o   ),
    .axi_aw_len_o    ( axi_aw_len_o    ),
    .axi_aw_size_o   ( axi_aw_size_o   ),
    .axi_aw_burst_o  ( axi_aw_burst_o  ),
    .axi_aw_lock_o   ( axi_aw_lock_o   ),
    .axi_aw_cache_o  ( axi_aw_cache_o  ),
    .axi_aw_qos_o    ( axi_aw_qos_o    ),
    .axi_aw_region_o ( axi_aw_region_o ),
    .axi_w_ready_i   ( axi_w_ready_i   ),
    .axi_w_valid_o   ( axi_w_valid_o   ),
    .axi_w_data_o    ( axi_w_data_o    ),
    .axi_w_strb_o    ( axi_w_strb_o    ),
    .axi_w_last_o    ( axi_w_last_o    ),
    .axi_w_user_o    ( axi_w_user_o    ),
    .axi_b_ready_o   ( axi_b_ready_o   ),
    .axi_b_valid_i   ( axi_b_valid_i   ),
    .axi_b_resp_i    ( axi_b_resp_i    ),
    .axi_b_id_i      ( axi_b_id_i      ),
    .axi_b_user_i    ( axi_b_user_i    ),
    .axi_ar_ready_i  ( axi_ar_ready_i  ),
    .axi_ar_valid_o  ( axi_ar_valid_o  ),
    .axi_ar_addr_o   ( axi_ar_addr_o   ),
    .axi_ar_prot_o   ( axi_ar_prot_o   ),
    .axi_ar_id_o     ( axi_ar_id_o     ),
    .axi_ar_user_o   ( axi_ar_user_o   ),
    .axi_ar_len_o    ( axi_ar_len_o    ),
    .axi_ar_size_o   ( axi_ar_size_o   ),
    .axi_ar_burst_o  ( axi_ar_burst_o  ),
    .axi_ar_lock_o   ( axi_ar_lock_o   ),
    .axi_ar_cache_o  ( axi_ar_cache_o  ),
    .axi_ar_qos_o    ( axi_ar_qos_o    ),
    .axi_ar_region_o ( axi_ar_region_o ),
    .axi_r_ready_o   ( axi_r_ready_o   ),
    .axi_r_valid_i   ( axi_r_valid_i   ),
    .axi_r_resp_i    ( axi_r_resp_i    ),
    .axi_r_data_i    ( axi_r_data_i    ),
    .axi_r_last_i    ( axi_r_last_i    ),
    .axi_r_id_i      ( axi_r_id_i      ),
    .axi_r_user_i    ( axi_r_user_i    )
);



endmodule //rv64im_core_top
