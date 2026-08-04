`include "rv64im_core_defines.sv"

module rv64im_core_satcnt (
    input  wire i_bx_cond,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:2] i_bx_pc,
    input  wire i_bx_pt,

    input  wire [`RV64IM_CORE_DATA_WIDTH-1:2] i_pred_pc,
    output wire o_pred_pt,     //取指令的地址
    output wire o_pred_vld,     //取指令的地址

    input  wire i_pred_en,
    input  wire clk,
    input  wire rstn
);
localparam BITS  = 10;
localparam DEPTH = 1<<BITS;
//===sp begin===
//===sp end===
    reg [1:0] sat_cnt [DEPTH-1:0];
    reg       cnt_vld [DEPTH-1:0];

    reg [1:0] cnt_val;
    reg pred_vld;

    wire [BITS-1:0]  pred_pc = i_pred_pc[2 +: BITS];
    wire [BITS-1:0]  bx_pc   = i_bx_pc[2 +: BITS];

    always @(posedge clk ) begin
        if (!rstn) begin
            cnt_val  <= 'b0;
            pred_vld <= 'b0;
        end else if(i_pred_en)begin
            cnt_val  <= sat_cnt[pred_pc[BITS-1:0]];
            pred_vld <= cnt_vld[pred_pc[BITS-1:0]];
        end
    end

    assign o_pred_pt  = cnt_val[1]; 
    assign o_pred_vld = pred_vld; 
    
    
generate for (genvar i=0;i<DEPTH-1;i=i+1) begin : u_gen_sat
    always @(posedge clk ) begin
        if (!rstn) begin
            sat_cnt[i] <= 2'b10;
        end else if(bx_pc[BITS-1:0]==i & i_bx_cond & i_bx_pt & ~(&sat_cnt[i])) begin  //2'b11
            sat_cnt[i] <= sat_cnt[i] + 1'b1;
        end else if(bx_pc[BITS-1:0]==i & i_bx_cond & ~i_bx_pt & (|sat_cnt[i])) begin  //2'b00
            sat_cnt[i] <= sat_cnt[i] - 1'b1;
        end
    end

    always @(posedge clk ) begin
        if (!rstn) begin
            cnt_vld[i] <= 1'b0;
        end else if(bx_pc[BITS-1:0]==i & i_bx_cond) begin
            cnt_vld[i] <= 1'b1;
        end
    end
end
endgenerate

endmodule
