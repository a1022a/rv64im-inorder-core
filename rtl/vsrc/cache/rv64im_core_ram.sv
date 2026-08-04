`include "rv64im_core_defines.sv"
module rv64im_core_ram#(
    parameter DATA_SIZE    = 64,    //write 64 bit in one clk
    parameter ADDR_SIZE    = 5,
    parameter DEPTH        = 32 
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

    wire [DATA_SIZE-1: 0] ram_wmask;

    wire [DATA_SIZE-1:0] QN   [3:0];
    wire CEN [3:0];
    wire CLK = clk;
    wire WEN = ~(i_ram_wen);
    wire [DATA_SIZE-1:0] BWEN = ~(ram_wmask);
    wire [ADDR_SIZE-1:0] AN   = i_ram_addr;
    wire [DATA_SIZE-1:0] DN   = i_ram_wdata;

generate  
    genvar i;  
    for (i=0; i<(DATA_SIZE/8); i=i+1) begin : gen_mask
        assign ram_wmask[(i*8) +: 8] = {8{i_ram_wmask[i]}};
    end
endgenerate


    reg [3:0] ram_bank_ff;
    always @(posedge clk or negedge rstn ) begin
        if (!rstn) begin
            ram_bank_ff <= 0;
        end else if(i_ram_cs) begin
            ram_bank_ff <= i_ram_bank_sel;
        end
    end    
    assign o_ram_rdata = ({DATA_SIZE{ram_bank_ff[0]}} & QN[0][DATA_SIZE-1:0])
                       | ({DATA_SIZE{ram_bank_ff[1]}} & QN[1][DATA_SIZE-1:0])
                       | ({DATA_SIZE{ram_bank_ff[2]}} & QN[2][DATA_SIZE-1:0])
                       | ({DATA_SIZE{ram_bank_ff[3]}} & QN[3][DATA_SIZE-1:0])
                       ;
generate  
genvar ii;  
for (ii=0; ii<4; ii=ii+1) begin : gen_bank_ram
    assign CEN[ii] = ~(i_ram_cs & i_ram_bank_sel[ii]);
S011HD1P_X32Y2D128_BW#(
    .Bits       (DATA_SIZE),
    .Word_Depth (DEPTH ),
    .Add_Width  (ADDR_SIZE),
    .Wen_Width  (DATA_SIZE)
)u_bank_ram(
    .Q          ( QN[ii] ),
    .CLK        ( CLK    ),
    .CEN        ( CEN[ii]),
    .WEN        ( WEN    ),
    .BWEN       ( BWEN   ),
    .A          ( AN     ),
    .D          ( DN     )
);
end
endgenerate

endmodule //rv64im_core_ram
