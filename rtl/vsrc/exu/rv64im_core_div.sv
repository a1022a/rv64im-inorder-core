`define MULDIV_VERILOG
module rv64im_core_div (
    input  wire [63:0] rs1,
    input  wire [63:0] rs2,

    input  wire is_signed,
    input  wire i_alu_div_req,
    input  wire i_stall,

    output wire [63:0] div_res,
    output wire [63:0] div_rem,
    output wire o_alu_div_ack,
    
    input  wire clk,
    input  wire rstn    
);

`ifdef MULDIV_VERILOG
    reg [5:0]  cnt;
    reg busy;

    wire rs1_sign = rs1[63];
    wire rs2_sign = rs2[63];
    reg op1_signed;
    reg op2_signed;

    wire busy_en = o_alu_div_ack ? ~i_stall : i_alu_div_req;
    always @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            busy <= 1'b0;
        end else if(busy_en) begin
            busy <= o_alu_div_ack ? i_stall : i_alu_div_req;
        end
    end
    
    wire [63:0] rs1_abs = is_signed & rs1_sign ? (~rs1+1'b1) : rs1;
    wire [63:0] rs2_abs = is_signed & rs2_sign ? (~rs2+1'b1) : rs2;
    wire [63:0] rvld_dec;
    wire [63:0] rvld_onehot;
    wire [63:0] dvld_dec;
    wire [63:0] dvld_onehot;
    reg [5:0]  rvld_cnt;
    reg [5:0]  dvld_cnt;
    reg [5:0]  rvld_cnt_r;
    reg [5:0]  dvld_cnt_r;
    wire div_done;
    wire fast_div;
    reg fast_div_r;

    assign rvld_onehot = rs1_abs & rvld_dec;
    assign dvld_onehot = rs2_abs & dvld_dec;

    assign rvld_dec[63:62] = {1'b1, ~rs1_abs[63]};
    assign dvld_dec[63:62] = {1'b1, ~rs2_abs[63]};

generate for(genvar i=0;i<62;i=i+1) begin : u_gen_rvld_dec
    assign rvld_dec[i] = ~ (|rs1_abs[63:i+1]);
    assign dvld_dec[i] = ~ (|rs2_abs[63:i+1]);
end
endgenerate

always @(*) begin
    rvld_cnt = 6'd0;
    for(integer i=0;i<64;i=i+1) begin
        if (rvld_onehot[i])
            rvld_cnt = i[5:0];
    end
end

always @(*) begin
    dvld_cnt = 6'd0;
    for(integer i=0;i<64;i=i+1) begin
        if (dvld_onehot[i])
            dvld_cnt = i[5:0];
    end
end

assign fast_div = ((rvld_dec & dvld_dec) == dvld_dec) & (rvld_dec!=dvld_dec) | ~(|dvld_onehot); //rs1 < rs2

assign div_done = ((rvld_cnt_r - dvld_cnt_r) == cnt) | fast_div_r; 


    always @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            op1_signed <= 1'b0;
            op2_signed <= 1'b0;
            fast_div_r <= 1'd0;
            rvld_cnt_r <= 6'd0;
            dvld_cnt_r <= 6'd0;
        end else if(i_alu_div_req & !busy) begin
            op1_signed <= is_signed & rs1_sign;
            op2_signed <= is_signed & rs2_sign;
            fast_div_r <= fast_div;
            rvld_cnt_r <= rvld_cnt;
            dvld_cnt_r <= dvld_cnt;
        end 
    end
    
    reg [63:0] rem_reg;
    reg [63:0] div_reg;
    reg [63:0] res_reg;

    wire [63:0] add_op1 = rem_reg;
    wire [63:0] add_op2 = div_reg;
 
    wire add_sign;
    wire [63:0] add_res;

    assign {add_sign, add_res} = {1'b0,add_op1} + ~{1'b0,add_op2} +1'b1;
    wire [63:0] sub_res = add_sign ?  add_op1 : add_res[63:0];

    wire [63:0] rem_reg_ns = ({64{~busy}} & (rs1_abs[63:0] << ~rvld_cnt))
                           | ({64{busy & ~fast_div_r}}  & sub_res[63:0])
                           | ({64{busy & fast_div_r}}   & rem_reg[63:0]) //keep rs1
                           ;
    wire [63:0] div_reg_ns = ({64{~busy}} & (rs2_abs[63:0] << ~dvld_cnt))
                           | ({64{busy}}  & {1'b0,div_reg[63:1]})
                           ;
    wire [63:0] res_reg_ns = ({64{~busy}} & 64'b0)
                           | ({64{busy}}  & {res_reg[62:0],~add_sign})
                           ;

    wire data_upd_en = o_alu_div_ack ? ~i_stall : (i_alu_div_req | busy);
    always @(posedge clk ) begin
        if(data_upd_en) begin
            rem_reg <= rem_reg_ns;
            div_reg <= div_reg_ns;
            res_reg <= res_reg_ns;
        end 
    end

    reg div_ready;
    wire div_ready_en = div_ready ? ~i_stall : busy;
    always @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            cnt <= 'b0;
            div_ready <= 1'b0;
        end else if(div_ready_en) begin
            cnt <= div_ready ? 6'd0 : cnt + 1'b1;
            div_ready <= div_ready ? 1'b0 : div_done;
        end
    end

    wire [63:0] div_res_sel = (op1_signed^op2_signed) ? (~res_reg + 1'b1) : res_reg;
    wire [63:0] rem_res_sel = (rem_reg >> ~rvld_cnt_r);
    assign div_res =  fast_div_r ? {64{~(|dvld_cnt_r)}} : div_res_sel;
    assign div_rem =  op1_signed ? (~rem_res_sel +1)    : rem_res_sel;


    assign o_alu_div_ack = div_ready;
`else
    assign div_res =  rs1 / rs2;
    assign div_rem =  rs1 % rs2;
    assign o_alu_div_ack = 1'b1;
`endif                    

    

endmodule //rv64im_core_muldiv
