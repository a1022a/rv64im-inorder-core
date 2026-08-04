`include "rv64im_core_defines.sv"

module rv64im_core_ras (
    input  wire i_bx_push,
    input  wire i_bx_pop,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_push_tgt,

    output wire o_pop_vld,     //取指令的地址
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_pop_tgt,

    input  wire clk,
    input  wire rstn
);

localparam BITS  = 5;
localparam DEPTH = 1<<BITS;

    reg [BITS-1:0] wptr;
    reg [DEPTH-1:0] tgt_vld;
    reg [`RV64IM_CORE_DATA_WIDTH-1:0] ret_tgt [DEPTH-1:0];

    wire [BITS-1:0] rptr = wptr - 1'b1;
    wire [BITS-1:0] wptr_next = wptr + {{(BITS-1){1'b0}}, i_bx_push} - {{(BITS-1){1'b0}}, i_bx_pop};

    always @(posedge clk ) begin
        if (!rstn) begin
            wptr  <= 'b0;
        end else if(i_bx_push | i_bx_pop)begin
            wptr  <= wptr_next;
        end
    end

    always @(posedge clk ) begin
        if(i_bx_push)begin
            ret_tgt[wptr]  <= i_push_tgt;
        end
    end

    always @(posedge clk ) begin
        if (!rstn) begin
            tgt_vld  <= 'b0;
        end else if(i_bx_push & ~i_bx_pop)begin
            tgt_vld[wptr]  <= 1'b1;
        end else if(~i_bx_push & i_bx_pop)begin
            tgt_vld[rptr]  <= 1'b0;
        end
    end

    assign o_pop_vld = tgt_vld[rptr];
    assign o_pop_tgt = ret_tgt[rptr];

endmodule
