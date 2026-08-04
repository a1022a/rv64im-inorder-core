module rv64im_core_compress_34to2
(
  input  wire [33:0]  in,
  input  wire [30:0]  ci,
  output wire [30:0]  co,
  output wire s,
  output wire c
);

/*
bits  num of 3to2   output         input
34    11            co[10:0]       34              stage0
23    7             co[17:11]      1+11+ci[10:0]   stage1
16    5             co[22:18]      2+7+ci[17:11]   stage2
11    3             co[25:23]      1+5+ci[22:18]   stage3
8     2             co[27:26]      2+3+ci[25:23]   stage4
6     2             co[29:28]      2+2+ci[27:26]   stage5
4     1             co[30]           2+ci[29:28]   stage6
3     1             (c,s)          1+1+ci[30]      stage7
*/
wire [10:0] s_tmp1;
wire [6:0] s_tmp2;
wire [4:0] s_tmp3;
wire [2:0] s_tmp4;
wire [1:0] s_tmp5;
wire [1:0] s_tmp6;
wire s_tmp7;

wire [22:0] in_tmp1;
wire [15:0] in_tmp2;
wire [10:0] in_tmp3;
wire [7:0] in_tmp4;
wire [5:0] in_tmp5;
wire [3:0] in_tmp6;
wire [2:0] in_tmp7;

generate for(genvar i=0;i<33;i=i+3) begin : u_stage_34to23
    rv64im_core_add_full u0_add_full(.a(in[i]), .b(in[i+1]),  .ci(in[i+2]), .sum(s_tmp1[i/3]),  .co(co[i/3]));
end
endgenerate

assign in_tmp1 = {s_tmp1[10:0],in[33],ci[10:0]};
generate for(genvar i=0;i<21;i=i+3) begin : u_stage_23to16
    rv64im_core_add_full u1_add_full(.a(in_tmp1[i]), .b(in_tmp1[i+1]),  .ci(in_tmp1[i+2]), .sum(s_tmp2[i/3]),  .co(co[11+i/3]));
end
endgenerate

assign in_tmp2 = {s_tmp2[6:0],in_tmp1[22:21],ci[17:11]};
generate for(genvar i=0;i<15;i=i+3) begin : u_stage_16to11
    rv64im_core_add_full u2_add_full(.a(in_tmp2[i]), .b(in_tmp2[i+1]),  .ci(in_tmp2[i+2]), .sum(s_tmp3[i/3]),  .co(co[18+i/3]));
end
endgenerate

assign in_tmp3 = {s_tmp3[4:0],in_tmp2[15],ci[22:18]};
generate for(genvar i=0;i<9;i=i+3) begin : u_stage_11to8
    rv64im_core_add_full u3_add_full(.a(in_tmp3[i]), .b(in_tmp3[i+1]),  .ci(in_tmp3[i+2]), .sum(s_tmp4[i/3]),  .co(co[23+i/3]));
end
endgenerate

assign in_tmp4 = {s_tmp4[2:0],in_tmp3[10:9],ci[25:23]};
generate for(genvar i=0;i<6;i=i+3) begin : u_stage_8to6
    rv64im_core_add_full u4_add_full(.a(in_tmp4[i]), .b(in_tmp4[i+1]),  .ci(in_tmp4[i+2]), .sum(s_tmp5[i/3]),  .co(co[26+i/3]));
end
endgenerate

assign in_tmp5 = {s_tmp5[1:0],in_tmp4[7:6],ci[27:26]};
generate for(genvar i=0;i<6;i=i+3) begin : u_stage_6to4
    rv64im_core_add_full u5_add_full(.a(in_tmp5[i]), .b(in_tmp5[i+1]),  .ci(in_tmp5[i+2]), .sum(s_tmp6[i/3]),  .co(co[28+i/3]));
end
endgenerate

assign in_tmp6 = {s_tmp6[1:0],ci[29:28]};
rv64im_core_add_full u6_add_full(.a(in_tmp6[0]), .b(in_tmp6[1]),  .ci(in_tmp6[2]), .sum(s_tmp7),  .co(co[30]));

assign in_tmp7 = {s_tmp7,in_tmp6[3],ci[30]};
rv64im_core_add_full u7_add_full(.a(in_tmp7[0]), .b(in_tmp7[1]),  .ci(in_tmp7[2]), .sum(s),  .co(c));

endmodule