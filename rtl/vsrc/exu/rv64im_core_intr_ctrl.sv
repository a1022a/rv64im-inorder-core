`include "rv64im_core_defines.sv"

module rv64im_core_intr_ctrl (

    // from core                              异步中断
    input wire [2:0] i_intr_req,              //2:外部中断 //1:软件中断 //0:计时器中断

    //form alu
    input  wire i_intr_ecall,
    input  wire i_intr_ebreak,
    input  wire i_intr_mret,
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_intr_pc,
    input  wire [`RV64IM_CORE_INST_WIDTH-1:0] i_intr_inst,
    output wire o_intr_alu_intr,

    // from csr_reg
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_intr_mtvec,           // read mtvec寄存器
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_intr_mepc,            // read mepc寄存器
    input  wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_intr_mstatus,         // read mstatus寄存器
    // to csr_reg
    output wire  o_intr_csr_wen,               // 写CSR寄存器标志
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_intr_mepc,           // 写mepc
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_intr_mstatus,        // 写mstatus
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_intr_mcause ,        // 写mcause
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_intr_mtval ,         // 写mtaval

    // to ctrl
    output wire o_intr_flush_en,          // 流水线冲刷
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_intr_flush_addr    // 中断入口地址    
);


    //同步异常
    //wire sync_intr = i_intr_ecall | i_intr_ebreak;      //目前同步异常只支持ecall,ebreak指令
    wire sync_intr = i_intr_ecall;      //ebreak 暂时作为程序终止命令 
    wire mret_intr = i_intr_mret ;                      //中断返回标志 ，INST_MRET   32'h30200073

    //异步中断
    wire global_intr_en = i_intr_mstatus[3];
    wire time_intr      = global_intr_en & i_intr_req[0];
    wire software_intr  = global_intr_en & i_intr_req[1];
    wire external_intr  = global_intr_en & i_intr_req[2];
    wire external_intr_sel = external_intr;
    wire software_intr_sel = software_intr & !external_intr;
    wire time_intr_sel     = time_intr & !external_intr & !software_intr;
    wire async_intr     = (external_intr_sel | software_intr_sel | time_intr_sel) & (i_intr_pc != 0);   //当正在执行nop指令时，等待

    wire intr_req  = sync_intr | async_intr;    
    wire intr_exit = mret_intr;
    //中断响应，中断返回时 的 流水线冲刷
    assign o_intr_flush_en  =   intr_req | intr_exit;
    assign o_intr_flush_addr = ({64{intr_req}}  & {i_intr_mtvec[63:2],2'b00})
                            |  ({64{intr_exit}} & i_intr_mepc)
                            ;
    //更新寄存器
    assign o_intr_csr_wen = intr_req | intr_exit;   
    assign o_intr_mepc =  intr_req ? i_intr_pc : 'b0;
    assign o_intr_mstatus =({`RV64IM_CORE_DATA_WIDTH{intr_req}} &{i_intr_mstatus[63:8], i_intr_mstatus[3], i_intr_mstatus[6:4], 1'b0,i_intr_mstatus[2:0]})
                        |  ({`RV64IM_CORE_DATA_WIDTH{intr_exit}}&{i_intr_mstatus[63:8], 1'b1, i_intr_mstatus[6:4], i_intr_mstatus[7], i_intr_mstatus[2:0]})
                        ;

    assign o_intr_mcause =i_intr_ecall         ? 64'd11
                    :     i_intr_ebreak        ? 64'd3                    
                    :     external_intr_sel ? 64'h800000000000000b
                    :     software_intr_sel ? 64'h8000000000000003
                    :     time_intr_sel     ? 64'h8000000000000007
                    :     'b0
                    ;
    assign o_intr_mtval  =  sync_intr   ? {32'b0,i_intr_inst} : 'b0;

    assign o_intr_alu_intr = async_intr;
endmodule //rv64im_core_intr_ctrl
