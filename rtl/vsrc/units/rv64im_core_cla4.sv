module rv64im_core_cla_4 (
    input wire [3:0] A,      // 4-bit 输入 A
    input wire [3:0] B,      // 4-bit 输入 B
    input wire Cin,           // 进位输入
    output wire [3:0] Sum,   // 4-bit 输出和
    output wire Pout,        //block进位传播信号
    output wire Gout,        //block进位生成信号
    output wire Cout          // 进位输出
);

    // 中间信号
    wire [3:0] G;            // 产生信号
    wire [3:0] P;            // 传播信号
    wire [4:0] C;            // 内部进位信号

    // 生成产生信号和传播信号
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_loop
            assign G[i] = A[i] & B[i];         // 产生信号
            assign P[i] = A[i] ^ B[i];         // 传播信号
        end
    endgenerate

    // 计算内部进位信号
    assign C[0] = Cin;
    assign C[1] = G[0] | (P[0] & C[0]);
    assign C[2] = G[1] | (P[1] & G[0]) | (P[1] & P[0] & C[0]);
    assign C[3] = G[2] | (P[2] & G[1]) | (P[2] & P[1] & G[0]) | (P[2] & P[1] & P[0] & C[0]);
    assign C[4] = G[3] | (P[3] & G[2]) | (P[3] & P[2] & G[1]) | (P[3] & P[2] & P[1] & G[0]) | (P[3] & P[2] & P[1] & P[0] & C[0]);

    assign Pout = P[0] & P[1] & P[2] & P[3];
    assign Gout = G[3] | (P[3] & G[2]) | (P[3] & P[2] & G[1]) | (P[3] & P[2] & P[1] & G[0]);
//  assign C[4] = Gout | Pout * C[0];

    // 计算最终的和
    assign Sum[0] = P[0] ^ C[0];
    assign Sum[1] = P[1] ^ C[1];
    assign Sum[2] = P[2] ^ C[2];
    assign Sum[3] = P[3] ^ C[3];

    // 最终的进位输出
    assign Cout = C[4];

endmodule