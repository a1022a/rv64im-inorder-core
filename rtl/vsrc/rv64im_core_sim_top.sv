module rv64im_core_sim_top
(
    output wire wb_sign,
    output wire [63:0] wb_pc,
    output wire [31:0] wb_inst,

    output wire wb_device,
    output wire wb_intr,
    output wire [63:0] intr_num,

    output wire [63:0] brn_num,
    output wire [63:0] bflush_num,

    output wire [63:0] st_addr,
    output wire [63:0] st_data,

    input  wire clk,
    input  wire rstn    
);

wire bx_wen     = u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_exu.u_rv64im_core_alu.bjp_req;
wire bflush_wen = u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_exu.u_rv64im_core_alu.o_alu_flush;
rv64im_core_reg #(.WIDTH(64), .RESET_VAL(64'd0)) u_bx     (.clk(clk), .rst(~rstn), .din(brn_num+1'b1),    .dout(brn_num),    .wen(bx_wen));
rv64im_core_reg #(.WIDTH(64), .RESET_VAL(64'd0)) u_bflush (.clk(clk), .rst(~rstn), .din(bflush_num+1'b1), .dout(bflush_num), .wen(bflush_wen));

wire async_intr = u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_exu.u_rv64im_core_intr_ctrl.async_intr;
wire[63:0] exu_pc = u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_exu.u_rv64im_core_alu.i_alu_pc;
reg [63:0] mem_pc;
reg [63:0] wbu_pc;
wire wb_wait = u_rv64im_core_top.u_rv64im_core_core.pipe_wbu_stall;
always @(posedge clk ) begin
    if (!rstn) begin
        mem_pc <= 64'h80000000;
        wbu_pc <= 64'h80000000;            
    end else if (!wb_wait)begin
        mem_pc <= async_intr ? 0 : exu_pc;
        wbu_pc <= mem_pc;        
    end
end

wire[31:0] exu_inst = u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_exu.u_rv64im_core_alu.i_alu_inst;
reg [31:0] mem_inst;
reg [31:0] wbu_inst;
always @(posedge clk ) begin
    if (!rstn) begin
        mem_inst <= 0;
        wbu_inst <= 0;        
    end else if (!wb_wait) begin
        mem_inst <= exu_inst;
        wbu_inst <= mem_inst;        
    end
end

wire wb_start = (mem_pc == 64'h80000004);
reg wb_buff;
always @(posedge clk) begin
    if (wb_start) begin
        wb_buff <= 1;
    end
end
assign  wb_sign = wb_start | (wb_buff & (wbu_pc != 0)&(!wb_wait));
assign  wb_pc   = wbu_pc;
assign  wb_inst = wbu_inst;


reg intr_buff;
always @(posedge clk) begin
    if (!rstn) begin
        intr_buff <= 0;
    end else if (async_intr) begin
        intr_buff <= 1;
    end else if (wb_sign & (wbu_pc == u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_exu.u_rv64im_core_csr_reg.mtvec)) begin
        intr_buff <= 0;
    end
end
assign  wb_intr   = intr_buff & (wbu_pc == u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_exu.u_rv64im_core_csr_reg.mtvec);
assign  intr_num  = u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_exu.u_rv64im_core_csr_reg.mcause;



//dpic 访问
import "DPI-C" function void set_ebreak(input logic ebreak);
logic ebreak = (wbu_inst == 32'h00100073);
import "DPI-C" function void set_gpr_ptr(input bit [63:0] a []);
bit [63:0] regs [32:0];
    genvar i;
    generate
        for (i = 0; i<33 ; i=i+1) begin
            if(i==0) begin
                assign regs[i] = 'b0;
            end else if(i==32) begin
                assign regs[i] = wb_pc;                
            end else begin
                assign regs[i] = u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_idu.u_rv64im_core_regfile.regs[i];                
            end
        end
    endgenerate
always @(*) begin
    set_ebreak(ebreak);
    set_gpr_ptr(regs);
end




//axi 访存控制；
import "DPI-C" function void mem_read (input int raddr, input bit ren, output bit[63:0] rdata);
import "DPI-C" function void mem_write(input int waddr, input longint wdata, input byte wmask,input bit wen);
    wire axi_aw_ready_i = axi_aw_valid_o;
    wire axi_aw_valid_o;
    wire [31:0] axi_aw_addr_o ;

    wire axi_w_ready_i = axi_w_valid_o;
    wire axi_w_valid_o ;
    wire [63:0] axi_w_data_o  ;
    wire [7:0] axi_w_strb_o  ;

    wire axi_b_ready_o ;
    wire axi_b_valid_i = axi_b_ready_o;

    wire axi_ar_ready_i = axi_ar_valid_o;
    wire axi_ar_valid_o;
    wire [31:0] axi_ar_addr_o ;

    wire axi_r_ready_o ;
    wire axi_r_valid_i = axi_r_ready_o;
    wire [63:0] axi_r_data_i  ;

wire ren = axi_r_ready_o & axi_r_valid_i;
wire wen = axi_b_ready_o & axi_b_valid_i;
reg [31:0] raddr,waddr;
always @(posedge clk ) begin
    raddr <= axi_ar_addr_o;
    waddr <= axi_aw_addr_o;
end
reg [63:0] wdata;
always @(posedge clk ) begin
    wdata <= axi_w_data_o;
end
reg [7:0] wmask;
always @(posedge clk ) begin
    wmask <= axi_w_strb_o;
end
always @(*) begin
    mem_read(raddr, ren, axi_r_data_i);
    mem_write(waddr, wdata, wmask, wen);
end

reg device_sign;
reg [63:0] wb_st_addr;

wire wb_ls_req =
    u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_lsu.reg_ls_req;

wire wb_ls_is_device =
      (u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_lsu.reg_ls_addr[31:28] == 4'ha)
    | (u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_lsu.reg_ls_addr[31:28] == 4'h2);

always @(posedge clk) begin
    if (!rstn) begin
        device_sign <= 1'b0;
        wb_st_addr  <= 64'b0;
    end else if (!wb_wait) begin
        /*
         * device_sign is a per-instruction writeback tag.
         * It must be cleared for bubbles and non-load/store instructions.
         */
        device_sign <= wb_ls_req & wb_ls_is_device;

        if (wb_ls_req) begin
            wb_st_addr <=
                u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_lsu.reg_ls_addr;
        end
    end
end

reg [63:0] wdata_ff;
reg [63:0] wb_st_wdata;
always @(posedge clk ) begin
    if (!wb_wait) begin
        wdata_ff    <=  u_rv64im_core_top.u_rv64im_core_core.u_rv64im_core_lsu.o_lsu_wdata[63:0];
        wb_st_wdata  <=  wdata_ff;
    end
end
assign  wb_device = device_sign;
assign  st_addr = wb_st_addr;
assign  st_data = wb_st_wdata;


rv64im_core_top#(
    .RW_DATA_WIDTH   ( 64 ),
    .RW_ADDR_WIDTH   ( 32 ),
    .AXI_DATA_WIDTH  ( 64 ),
    .AXI_ADDR_WIDTH  ( 32 ),
    .AXI_ID_WIDTH    ( 4 ),
    .AXI_STRB_WIDTH  ( 8 ),
    .AXI_USER_WIDTH  ( 1 )
)u_rv64im_core_top(
    .axi_aw_ready_i  ( axi_aw_ready_i  ),
    .axi_aw_valid_o  ( axi_aw_valid_o  ),
    .axi_aw_addr_o   ( axi_aw_addr_o   ),
//
    .axi_aw_prot_o   ( ),
    .axi_aw_id_o     ( ),
    .axi_aw_user_o   ( ),
    .axi_aw_len_o    ( ),
    .axi_aw_size_o   ( ),
    .axi_aw_burst_o  ( ),
    .axi_aw_lock_o   ( ),
    .axi_aw_cache_o  ( ),
    .axi_aw_qos_o    ( ),
    .axi_aw_region_o ( ),
//
    .axi_w_ready_i   ( axi_w_ready_i   ),
    .axi_w_valid_o   ( axi_w_valid_o   ),
    .axi_w_data_o    ( axi_w_data_o    ),
    .axi_w_strb_o    ( axi_w_strb_o    ),
//
    .axi_w_last_o    ( ),
    .axi_w_user_o    ( ),
//
    .axi_b_ready_o   ( axi_b_ready_o   ),
    .axi_b_valid_i   ( axi_b_valid_i   ),
//
    .axi_b_resp_i    ( ),
    .axi_b_id_i      ( ),
    .axi_b_user_i    ( ),
//
    .axi_ar_ready_i  ( axi_ar_ready_i  ),
    .axi_ar_valid_o  ( axi_ar_valid_o  ),
    .axi_ar_addr_o   ( axi_ar_addr_o   ),
//
    .axi_ar_prot_o   (  ),
    .axi_ar_id_o     (  ),
    .axi_ar_user_o   (  ),
    .axi_ar_len_o    (  ),
    .axi_ar_size_o   (  ),
    .axi_ar_burst_o  (  ),
    .axi_ar_lock_o   (  ),
    .axi_ar_cache_o  (  ),
    .axi_ar_qos_o    (  ),
    .axi_ar_region_o (  ),
//
    .axi_r_ready_o   ( axi_r_ready_o   ),
    .axi_r_valid_i   ( axi_r_valid_i   ),
    .axi_r_data_i    ( axi_r_data_i    ),
//
    .axi_r_resp_i    (  ),
    .axi_r_last_i    (  ),
    .axi_r_id_i      (  ),
    .axi_r_user_i    (  ),

    .clk              ( clk               ),
    .rstn              ( rstn               )
//
);

endmodule

