`include "rv64im_core_defines.sv"

module rv64im_core_sram64x64 (
    input  wire        clk,
    input  wire        cs,
    input  wire        wen,
    input  wire [5:0]  addr,
    input  wire [63:0] wdata,
    input  wire [7:0]  wmask,
    output wire [63:0] rdata
);

`ifdef ASIC_SRAM
    wire [63:0] bweb;
    wire [63:0] q;
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_bit_write_mask
            assign bweb[i*8 +: 8] = {8{~wmask[i]}};
        end
    endgenerate
    TEM5N28HPCPLVTA64X64M4SWSO u_sram (
        .SLP(1'b0), .SD(1'b0), .A(addr), .D(wdata), .BWEB(bweb), .Q(q),
        .WEB(~wen), .CEB(~cs), .CLK(clk)
    );
    assign rdata = q;
`else
    reg [63:0] mem [0:63];
    reg [63:0] rdata_q;
    integer j;
    always @(posedge clk) begin
        if (cs) begin
            rdata_q <= mem[addr];
            if (wen) begin
                for (j = 0; j < 8; j = j + 1)
                    if (wmask[j]) mem[addr][j*8 +: 8] <= wdata[j*8 +: 8];
            end
        end
    end
    assign rdata = rdata_q;
`endif

endmodule
