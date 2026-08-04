`include "rv64im_core_defines.sv"

module rv64im_core_pipe_ctrl (
    // from ex
    input wire i_pipec_exu_stall,         
    input wire i_pipec_exu_flush,      
    input wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_pipec_exu_flush_addr,    //执行阶段冲刷地址
    // from mem
    input wire i_pipec_mem_stall,
    input wire i_pipec_idu_stall,     
    // from intr
    input wire i_pipec_intr_flush,          //取指状态 ecall产生 同步 异常，这时保证pc寄存器不变
    input wire [`RV64IM_CORE_DATA_WIDTH-1:0] i_pipec_intr_flush_addr,    
    //to pipeline 
    output wire [4:0] o_pipec_stall,       //stall: all pipe
    output wire [4:0] o_pipec_flush,       //flush: if,id,ex regs
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] o_pipec_flush_addr //to if
);
    //exu跳转指令，mem访存stall时处理；
    //{wbu,mmu,exu,idu,ifu}
    assign o_pipec_stall =  ({5{i_pipec_exu_stall | i_pipec_mem_stall}})
                          | ({5{i_pipec_idu_stall}} & 5'b00011)
                          ;

    assign o_pipec_flush =  ({5{i_pipec_intr_flush }} & {1'b0, !i_pipec_mem_stall, 3'b111}) //exu inst will be flushed, can't go lsu
                          | ({5{i_pipec_exu_flush & !i_pipec_mem_stall }} & 5'b00111)       //exu inst not  be flushed, can go lsu
                          | ({5{i_pipec_idu_stall & !i_pipec_mem_stall }} & 5'b00100)       //exu inst not  be flushed, can go lsu
                          ;

    assign o_pipec_flush_addr = i_pipec_intr_flush ? i_pipec_intr_flush_addr
                              : i_pipec_exu_flush  ? i_pipec_exu_flush_addr
                              : 'b0;

endmodule //rv64im_core_pipe_ctrl