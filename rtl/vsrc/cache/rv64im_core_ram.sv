`include "rv64im_core_defines.sv"
module rv64im_core_ram#(
    parameter DATA_SIZE    = 64,
    parameter ADDR_SIZE    = 6,
    parameter DEPTH        = 64
)(
    input  wire                     i_ram_cs,
    input  wire [ADDR_SIZE-1:0]     i_ram_addr,
    input  wire [3:0]               i_ram_bank_sel,
    input  wire                     i_ram_wen,
    input  wire [DATA_SIZE-1:0]     i_ram_wdata,
    input  wire [(DATA_SIZE/8)-1:0] i_ram_wmask,
    output wire [DATA_SIZE-1:0]     o_ram_rdata,
    input  wire clk,
    input  wire rstn
);

    wire [DATA_SIZE-1:0] ram_rdata [3:0];
    wire [5:0] sram_addr = i_ram_addr[5:0];


    reg [3:0] ram_bank_ff;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            ram_bank_ff <= 4'b0;
        end else if (i_ram_cs) begin
            ram_bank_ff <= i_ram_bank_sel;
        end
    end
    assign o_ram_rdata = ({DATA_SIZE{ram_bank_ff[0]}} & ram_rdata[0])
                       | ({DATA_SIZE{ram_bank_ff[1]}} & ram_rdata[1])
                       | ({DATA_SIZE{ram_bank_ff[2]}} & ram_rdata[2])
                       | ({DATA_SIZE{ram_bank_ff[3]}} & ram_rdata[3]);

    generate
        genvar ii;
        for (ii = 0; ii < 4; ii = ii + 1) begin : gen_bank_ram
            rv64im_core_sram64x64 u_bank_ram (
                .clk   (clk),
                .cs    (i_ram_cs & i_ram_bank_sel[ii]),
                .wen   (i_ram_wen),
                .addr  (sram_addr),
                .wdata (i_ram_wdata[63:0]),
                .wmask (i_ram_wmask[7:0]),
                .rdata (ram_rdata[ii])
            );
        end
    endgenerate

endmodule //rv64im_core_ram
