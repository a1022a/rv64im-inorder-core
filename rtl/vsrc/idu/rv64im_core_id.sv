`include "rv64im_core_defines.sv"

module rv64im_core_id (
    input  wire [`RV64IM_CORE_INST_WIDTH-1:0] i_id_inst,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_id_pc,

    output wire [`RV64IM_CORE_INST_WIDTH-1:0] o_id_inst,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_id_pc,

    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_id_imm_data,
    output wire [4:0] o_id_rs1_index,
    output wire [4:0] o_id_rs2_index,
    output wire [4:0] o_id_rd_index,

    output wire [`RV64IM_CORE_TYPE_INFO-1:0] o_id_type_info,
    output wire [`RV64IM_CORE_OP_INFO-1:0] o_id_op_info

);
    assign o_id_pc = i_id_pc;
    assign o_id_inst = i_id_inst;

//decode
    wire [4:0] rs1 = i_id_inst[19:15];
    wire [4:0] rs2 = i_id_inst[24:20];
    wire [4:0] rd  = i_id_inst[11: 7];

    wire [6:0] opcode = i_id_inst[6:0];
    wire [2:0] fun3 = i_id_inst[14:12];
    wire [6:0] fun7 = i_id_inst[31:25];

//type
    wire dec_r  = (opcode == 7'b0110011) & (fun7[4:0] == 5'b0);
    wire dec_rw = (opcode == 7'b0111011) & (fun7[4:0] == 5'b0);
    wire dec_ri = (opcode == 7'b0010011) ;
    wire dec_riw= (opcode == 7'b0011011) ;
    wire dec_md = (opcode == 7'b0110011) & (fun7 == 7'b0000001);
    wire dec_mdw= (opcode == 7'b0111011) & (fun7 == 7'b0000001);

    wire dec_branch = (opcode == 7'b1100011);
    wire dec_jal  = (opcode == 7'b1101111);
    wire dec_jalr = (opcode == 7'b1100111) & (fun3 == 3'b000);

    wire dec_ld   = (opcode == 7'b0000011);
    wire dec_st   = (opcode == 7'b0100011);

    wire dec_lui     = (opcode == 7'b0110111);
    wire dec_auipc   = (opcode == 7'b0010111);

    wire dec_csr   = (opcode == 7'b1110011);
//op
    //rv64im_core_ALU_INFO
    wire [4:0] op_code = {i_id_inst[31:30],fun3};
    wire alu_op = dec_r | dec_ri | dec_auipc | dec_lui | dec_rw | dec_riw;
    wire add_op = dec_auipc | ((dec_r | dec_rw ) & (op_code == 5'b00000)) | ((dec_ri | dec_riw ) & (op_code[2:0] == 3'b000));
    wire sub_op = (dec_r | dec_rw) & (op_code == 5'b01000);
    wire sll_op = (dec_ri | ((dec_r | dec_rw | dec_riw) & (fun7[0] == 1'b0))) & (op_code == 5'b00001) & (fun7[4:1] == 4'b0);
    wire srl_op = (dec_ri | ((dec_r | dec_rw | dec_riw) & (fun7[0] == 1'b0))) & (op_code == 5'b00101) & (fun7[4:1] == 4'b0);
    wire sra_op = (dec_ri | ((dec_r | dec_rw | dec_riw) & (fun7[0] == 1'b0))) & (op_code == 5'b01101) & (fun7[4:1] == 4'b0);
    wire slt_op = ((dec_r & fun7[6:5]==2'b00) | dec_ri ) & (op_code[2:0] == 3'b010);
    wire sltu_op= ((dec_r & fun7[6:5]==2'b00) | dec_ri ) & (op_code[2:0] == 3'b011);
    wire xor_op = ((dec_r & fun7[6:5]==2'b00) | dec_ri ) & (op_code[2:0] == 3'b100);
    wire or_op  = ((dec_r & fun7[6:5]==2'b00) | dec_ri ) & (op_code[2:0] == 3'b110);
    wire and_op = ((dec_r & fun7[6:5]==2'b00) | dec_ri ) & (op_code[2:0] == 3'b111);
    wire op2_imm= dec_ri | dec_riw | dec_auipc;
    wire op1_pc = dec_auipc;
    wire res_imm= dec_lui;
    wire alu_sext_w = dec_rw | dec_riw;//sext(result[31:0])
    wire[`RV64IM_CORE_ALU_INFO-1:0] alu_info = {add_op , sub_op , sll_op , srl_op , sra_op , slt_op , sltu_op , xor_op , or_op , and_op , op2_imm , op1_pc , res_imm , alu_sext_w};
    //mem_info
    wire mem_op = dec_ld | dec_st;
    wire lb = dec_ld & (fun3 == 3'b000);
    wire lh = dec_ld & (fun3 == 3'b001);
    wire lw = dec_ld & (fun3 == 3'b010);
    wire ld = dec_ld & (fun3 == 3'b011);
    wire lbu= dec_ld & (fun3 == 3'b100);
    wire lhu= dec_ld & (fun3 == 3'b101);
    wire lwu= dec_ld & (fun3 == 3'b110);
    wire sb = dec_st & (fun3 == 3'b000);
    wire sh = dec_st & (fun3 == 3'b001);
    wire sw = dec_st & (fun3 == 3'b010);
    wire sd = dec_st & (fun3 == 3'b011);
    wire rw_ctrl = dec_ld;
    wire [`RV64IM_CORE_MEM_INFO-1:0] mem_info = {lb , lh , lw , ld , lbu , lhu , lwu , sb , sh , sw , sd , rw_ctrl};
    //bjp_info
    wire bjp_op = dec_branch | dec_jalr | dec_jal;
    wire beq = dec_branch & (fun3 == 3'b000);
    wire bne = dec_branch & (fun3 == 3'b001);
    wire blt = dec_branch & (fun3 == 3'b100);
    wire bge = dec_branch & (fun3 == 3'b101);
    wire bltu= dec_branch & (fun3 == 3'b110);
    wire bgeu= dec_branch & (fun3 == 3'b111);
    wire jal = dec_jal;
    wire jalr= dec_jalr;
    wire [`RV64IM_CORE_BJP_INFO-1:0] bjp_info = {beq , bne , blt , bge , bltu , bgeu , jal , jalr};
    //muldiv_info;
    wire muldiv_op = dec_md | dec_mdw;
    wire mul   = muldiv_op & (fun3 == 3'b000);
    wire mulh  = dec_md & (fun3 == 3'b001);
    wire mulhsu= dec_md & (fun3 == 3'b010);
    wire mulhu = dec_md & (fun3 == 3'b011);
    wire div   = muldiv_op & (fun3 == 3'b100);
    wire divu  = muldiv_op & (fun3 == 3'b101);
    wire rem   = muldiv_op & (fun3 == 3'b110);
    wire remu  = muldiv_op & (fun3 == 3'b111);
    wire md_sext_w = dec_mdw;
    wire [`RV64IM_CORE_MULDIV_INFO-1:0] muldiv_info = {mul , mulh , mulhsu , mulhu , div , divu , rem , remu , md_sext_w};
    //sys_info;
    wire fence  = (opcode == 7'b0001111) & {i_id_inst[31:28],i_id_inst[19:7]} == 'b0;
    wire fencei = i_id_inst == 32'h0000100f;
    wire ecall  = i_id_inst == 32'h00000073;
    wire ebreak = i_id_inst == 32'h00100073;
    wire mret   = i_id_inst == 32'h30200073;
    wire sys_op = fence | fencei | ecall | ebreak | mret;
    wire [`RV64IM_CORE_SYS_INFO-1:0] sys_info = {fence,fencei,ecall,ebreak,mret};
    //csr_info;
    wire csr_op = dec_csr;
    wire csrrw =  (dec_csr) & (fun3 == 3'b001);
    wire csrrs =  (dec_csr) & (fun3 == 3'b010);
    wire csrrc =  (dec_csr) & (fun3 == 3'b011);
    wire csrrwi = (dec_csr) & (fun3 == 3'b101);
    wire csrrsi = (dec_csr) & (fun3 == 3'b110);
    wire csrrci = (dec_csr) & (fun3 == 3'b111);
    wire [`RV64IM_CORE_CSR_INFO-1:0] csr_info = {csrrw , csrrs , csrrc , csrrwi , csrrsi , csrrci};


    assign o_id_type_info = {csr_op, sys_op, muldiv_op, bjp_op, mem_op, alu_op};
    assign o_id_op_info   =         ({`RV64IM_CORE_OP_INFO{alu_op}} & {alu_info}) 
                                |({`RV64IM_CORE_OP_INFO{mem_op}} & {mem_info,{(`RV64IM_CORE_OP_INFO-`RV64IM_CORE_MEM_INFO){1'b0}}}) 
                                |({`RV64IM_CORE_OP_INFO{bjp_op}} & {bjp_info,{(`RV64IM_CORE_OP_INFO-`RV64IM_CORE_BJP_INFO){1'b0}}}) 
                                |({`RV64IM_CORE_OP_INFO{muldiv_op}} & {muldiv_info,{(`RV64IM_CORE_OP_INFO-`RV64IM_CORE_MULDIV_INFO){1'b0}}}) 
                                |({`RV64IM_CORE_OP_INFO{sys_op}} & {sys_info,{(`RV64IM_CORE_OP_INFO-`RV64IM_CORE_SYS_INFO){1'b0}}})
                                |({`RV64IM_CORE_OP_INFO{csr_op}} & {csr_info,{(`RV64IM_CORE_OP_INFO-`RV64IM_CORE_CSR_INFO){1'b0}}}) 
                                ; 
//generate imm
    wire type_i =  dec_ld|dec_jalr|dec_ri|dec_riw;
    wire type_u =  dec_auipc|dec_lui;
    wire type_s =  dec_st;
    wire type_b =  dec_branch;
    wire type_j =  dec_jal;


    wire [`RV64IM_CORE_DATA_WIDTH-1:0] imm_i = {{52{i_id_inst[31]}}, i_id_inst[31:20]};                                                       //ri, jalr, load
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] imm_u = {{32{i_id_inst[31]}},  i_id_inst[31:12],    12'b0};                                                               //aui_pc,lui
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] imm_s = {{52{i_id_inst[31]}}, i_id_inst[31:25], i_id_inst[11:7]};                                      //store
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] imm_b = {{52{i_id_inst[31]}}, i_id_inst[7], i_id_inst[30:25], i_id_inst[11:8], 1'b0};                  //jump
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] imm_j = {{43{i_id_inst[31]}}, i_id_inst[31], i_id_inst[19:12], i_id_inst[20], i_id_inst[30:21], 1'b0}; //jal

    assign o_id_imm_data = (imm_i & {`RV64IM_CORE_DATA_WIDTH{type_i}}) 
                         | (imm_u & {`RV64IM_CORE_DATA_WIDTH{type_u}})
                         | (imm_s & {`RV64IM_CORE_DATA_WIDTH{type_s}}) 
                         | (imm_b & {`RV64IM_CORE_DATA_WIDTH{type_b}}) 
                         | (imm_j & {`RV64IM_CORE_DATA_WIDTH{type_j}})    
                         ;
    assign o_id_rs1_index = rs1;
    assign o_id_rs2_index = rs2;
    assign o_id_rd_index = rd;


endmodule //idu
