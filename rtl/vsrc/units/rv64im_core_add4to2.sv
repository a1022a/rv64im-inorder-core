module rv64im_core_add_4to2 #(
    parameter BITS = 4
)
(
  input  wire [BITS-1:0]  i1,
  input  wire [BITS-1:0]  i2,
  input  wire [BITS-1:0]  i3,
  input  wire [BITS-1:0]  i4,
  output wire [BITS-1:0]  o1,
  output wire [BITS-1:0]  o2
);

  wire [BITS-1:0] tmp_o1;
  wire [BITS-1:0] tmp_o2;
  wire [BITS-1:0] tmp_i1;
  wire [BITS-1:0] tmp_i2;
  wire [BITS-1:0] tmp_co;

generate for(genvar i=0;i<BITS;i=i+1) begin : u_add_4to2
    rv64im_core_add_full u0_add_full(
        .a   ( i1[i]  ),
        .b   ( i2[i]  ),
        .ci  ( i3[i]  ),
        .sum ( tmp_o1[i] ),
        .co  ( tmp_o2[i] )
    );

    rv64im_core_add_full u1_add_full(
        .a   ( tmp_i1[i] ),
        .b   ( tmp_i2[i] ),
        .ci  ( i4[i] ),
        .sum ( o1[i] ),
        .co  ( tmp_co[i] )
    );
end
  assign o2 = {tmp_co[BITS-2:0],1'b0};
endgenerate

  assign tmp_i1[0] = 1'b0;
  assign tmp_i2[0] = tmp_o2[i];
generate for(genvar i=1;i<BITS;i=i+1) begin : u_tmp_connect
  assign tmp_i1[i] = tmp_o1[i]; 
  assign tmp_i2[i] = tmp_o2[i-1]; 
end
endgenerate
endmodule