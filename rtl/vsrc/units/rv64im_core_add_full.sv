module rv64im_core_add_full 
(
  input  a,
  input  b,
  input  ci,
  output sum,
  output co
);
  assign sum = a ^ b ^ ci;              //set 1 when (0 0 1) (1 1 1)
  assign co  = (a&b) | (a&ci) | (b&ci); //set 1 when (0 1 1)
endmodule