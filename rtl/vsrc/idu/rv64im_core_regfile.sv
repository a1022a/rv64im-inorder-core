`include "rv64im_core_defines.sv"

module rv64im_core_regfile (
    input  wire [`RV64IM_CORE_INST_WIDTH-1:0] i_rf_inst,
    input  wire i_rf_wb_stall,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_rf_rd_data,
    input  wire [4:0] i_rf_rd_index,
    input  wire i_rf_rd_wen,

    input  wire i_rf_exu_load,
    input  wire i_rf_exu_rd_wen,
    input  wire [4:0] i_rf_exu_rd_index,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_rf_exu_rd_data,
    input  wire i_rf_mem_rd_wen,
    input  wire [4:0] i_rf_mem_rd_index,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_rf_mem_rd_data,
    output wire o_rf_id_flush_ex,

    input  wire [4:0] i_rf_rs1_index,
    input  wire [4:0] i_rf_rs2_index,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_rf_rs1_data,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_rf_rs2_data,

    input  wire clk,
    input  wire rstn
);

    wire[`RV64IM_CORE_DATA_WIDTH-1:0] regs [32-1:0];
    wire[32-1:0] we;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin: gpr_rw
            // x0 cannot be wrote since it is constant-zeros
            if (i == 0) begin: is_x0
                assign we[i] = 1'b0;
                assign regs[i] = 64'h0;
            end else begin: not_x0
                assign we[i] = i_rf_rd_wen & !i_rf_wb_stall & (i_rf_rd_index == i);
                rv64im_core_reg #(`RV64IM_CORE_DATA_WIDTH,0) rf_reg(clk,!rstn,i_rf_rd_data,regs[i],we[i]);
            end
        end
    endgenerate

    wire exu_hit_rs1 = (i_rf_rs1_index == i_rf_exu_rd_index) &  i_rf_exu_rd_wen & (!i_rf_exu_load);
    wire mem_hit_rs1 = (i_rf_rs1_index == i_rf_mem_rd_index) &  i_rf_mem_rd_wen ;
    wire wbu_hit_rs1 = (i_rf_rs1_index == i_rf_rd_index) & i_rf_rd_wen;

    wire exu_hit_rs2 = (i_rf_rs2_index == i_rf_exu_rd_index) &  i_rf_exu_rd_wen & (!i_rf_exu_load);
    wire mem_hit_rs2 = (i_rf_rs2_index == i_rf_mem_rd_index) &  i_rf_mem_rd_wen ;
    wire wbu_hit_rs2 = (i_rf_rs2_index == i_rf_rd_index) & i_rf_rd_wen;

    wire [6:0] opcode = i_rf_inst[6:0];
    wire [2:0] funct3 = i_rf_inst[14:12];
    wire use_rs1 = (opcode == 7'b0110011) | (opcode == 7'b0111011)
                 | (opcode == 7'b0100011) | (opcode == 7'b1100011)
                 | (opcode == 7'b0000011) | (opcode == 7'b0010011)
                 | (opcode == 7'b0011011) | (opcode == 7'b1100111)
                 | ((opcode == 7'b1110011) & (funct3 >= 3'b001) & (funct3 <= 3'b011));
    wire use_rs2 = (opcode == 7'b0110011) | (opcode == 7'b0111011)
                 | (opcode == 7'b0100011) | (opcode == 7'b1100011);
    wire load_use_rs1 = use_rs1 & (i_rf_rs1_index == i_rf_exu_rd_index);
    wire load_use_rs2 = use_rs2 & (i_rf_rs2_index == i_rf_exu_rd_index);
    assign o_rf_id_flush_ex = i_rf_exu_rd_wen & i_rf_exu_load
                            & (i_rf_exu_rd_index != 5'b0)
                            & (load_use_rs1 | load_use_rs2);

    assign o_rf_rs1_data = (i_rf_rs1_index==0) ?  'b0
                         : exu_hit_rs1 ? i_rf_exu_rd_data
                         : mem_hit_rs1 ? i_rf_mem_rd_data
                         : wbu_hit_rs1 ? i_rf_rd_data
                         : regs[i_rf_rs1_index];
            
    assign o_rf_rs2_data = (i_rf_rs2_index==0) ?  'b0
                         : exu_hit_rs2 ? i_rf_exu_rd_data
                         : mem_hit_rs2 ? i_rf_mem_rd_data
                         : wbu_hit_rs2 ? i_rf_rd_data
                         : regs[i_rf_rs2_index];

endmodule //rv64im_core_regfile
