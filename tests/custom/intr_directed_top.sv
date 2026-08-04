`include "rv64im_core_defines.sv"

module intr_directed_top (
    input  wire clk,
    output reg  done,
    output reg  fail,
    output reg [7:0] failed_state,
    output reg [`RV64IM_CORE_DATA_WIDTH-1:0] observed,
    output wire mret_check_phase,
    output wire mret_check_flush_en,
    output wire [`RV64IM_CORE_DATA_WIDTH-1:0] mret_check_flush_addr
);
    reg rstn;
    reg [7:0] state;

    reg [2:0] intr_source;
    reg [`RV64IM_CORE_DATA_WIDTH-1:0] csr_wdata;
    reg csr_wen;
    reg [11:0] csr_addr;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] csr_rdata;

    wire [2:0] csr_intr_req;
    wire intr_csr_wen;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] intr_mstatus;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] intr_mepc;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] intr_mcause;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] intr_mtval;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] csr_mstatus;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] csr_mtvec;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] csr_mepc;

    reg intr_ecall;
    reg intr_ebreak;
    reg intr_mret;
    reg [`RV64IM_CORE_DATA_WIDTH-1:0] intr_pc;
    reg [`RV64IM_CORE_INST_WIDTH-1:0] intr_inst;
    wire intr_alu_intr;
    wire intr_flush_en;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] intr_flush_addr;
    wire intr_mret_drive = intr_mret & !clk;

    reg clt_req_vld;
    reg clt_wen;
    reg [`RV64IM_CORE_DATA_WIDTH-1:0] clt_addr;
    reg [`RV64IM_CORE_DATA_WIDTH-1:0] clt_wdata;
    wire clt_req_rdy;
    wire [`RV64IM_CORE_DATA_WIDTH-1:0] clt_rdata;
    wire clt_rsp_vld;
    wire clt_msip;
    wire clt_mtip;

    rv64im_core_csr_reg u_csr (
        .i_cr_intr_source  (intr_source),
        .o_cr_intr_req     (csr_intr_req),
        .i_cr_wdata        (csr_wdata),
        .i_cr_wen          (csr_wen),
        .i_cr_addr         (csr_addr),
        .o_cr_rdata        (csr_rdata),
        .i_cr_intr_wen     (intr_csr_wen),
        .i_cr_intr_mstatus (intr_mstatus),
        .i_cr_intr_mepc    (intr_mepc),
        .i_cr_intr_mcause  (intr_mcause),
        .i_cr_intr_mtval   (intr_mtval),
        .o_cr_intr_mstatus (csr_mstatus),
        .o_cr_intr_mtvec   (csr_mtvec),
        .o_cr_intr_mepc    (csr_mepc),
        .clk               (clk),
        .rstn              (rstn)
    );

    rv64im_core_intr_ctrl u_intr (
        .i_intr_req        (csr_intr_req),
        .i_intr_ecall      (intr_ecall),
        .i_intr_ebreak     (intr_ebreak),
        .i_intr_mret       (intr_mret_drive),
        .i_intr_pc         (intr_pc),
        .i_intr_inst       (intr_inst),
        .o_intr_alu_intr   (intr_alu_intr),
        .i_intr_mtvec      (csr_mtvec),
        .i_intr_mepc       (csr_mepc),
        .i_intr_mstatus    (csr_mstatus),
        .o_intr_csr_wen    (intr_csr_wen),
        .o_intr_mepc       (intr_mepc),
        .o_intr_mstatus    (intr_mstatus),
        .o_intr_mcause     (intr_mcause),
        .o_intr_mtval      (intr_mtval),
        .o_intr_flush_en   (intr_flush_en),
        .o_intr_flush_addr (intr_flush_addr)
    );

    assign mret_check_phase = (state == 8'd15) & intr_mret & !clk;
    assign mret_check_flush_en = intr_flush_en;
    assign mret_check_flush_addr = intr_flush_addr;

    rv64im_core_clint u_clint (
        .i_clt_req_vld (clt_req_vld),
        .i_clt_wen     (clt_wen),
        .i_clt_addr    (clt_addr),
        .i_clt_wdata   (clt_wdata),
        .i_clt_wmask   (8'hff),
        .o_clt_req_rdy (clt_req_rdy),
        .i_clt_rsp_rdy (1'b1),
        .o_clt_rdata   (clt_rdata),
        .o_clt_rsp_vld (clt_rsp_vld),
        .o_clt_msip    (clt_msip),
        .o_clt_mtip    (clt_mtip),
        .clk           (clk),
        .rstn          (rstn)
    );

    task automatic csr_write(input [11:0] addr, input [`RV64IM_CORE_DATA_WIDTH-1:0] data);
        begin
            csr_wen = 1'b1;
            csr_addr = addr;
            csr_wdata = data;
        end
    endtask

    task automatic csr_read(input [11:0] addr);
        begin
            csr_wen = 1'b0;
            csr_addr = addr;
            csr_wdata = '0;
        end
    endtask

    task automatic check(input cond);
        begin
            if (!cond) begin
                fail = 1'b1;
                done = 1'b1;
                failed_state = state;
                observed = csr_rdata;
            end
        end
    endtask

    initial begin
        rstn = 1'b0;
        state = 8'd0;
        done = 1'b0;
        fail = 1'b0;
        failed_state = 8'd0;
        observed = '0;
        intr_source = 3'b000;
        csr_wdata = '0;
        csr_wen = 1'b0;
        csr_addr = 12'h300;
        intr_ecall = 1'b0;
        intr_ebreak = 1'b0;
        intr_mret = 1'b0;
        intr_pc = 64'h8000_0100;
        intr_inst = 32'h0000_0013;
        clt_req_vld = 1'b0;
        clt_wen = 1'b0;
        clt_addr = '0;
        clt_wdata = '0;
    end

    always @(negedge clk) begin
        if (!done) begin
            csr_wen = 1'b0;
            intr_ecall = 1'b0;
            intr_ebreak = 1'b0;
            clt_req_vld = 1'b0;
            clt_wen = 1'b0;

            case (state)
                8'd0: begin
                    rstn = 1'b0;
                    state = 8'd1;
                end
                8'd1: begin
                    rstn = 1'b1;
                    state = 8'd2;
                end

                // Case A: MTIP=1, MTIE=0, MIE=1 => no timer trap.
                8'd2: begin
                    intr_source = 3'b001;
                    csr_write(12'h304, 64'h0);
                    state = 8'd3;
                end
                8'd3: begin
                    csr_write(12'h300, 64'h8);
                    state = 8'd4;
                end
                8'd4: begin
                    check(!intr_flush_en && !intr_alu_intr);
                    state = 8'd5;
                end

                // Case B: MTIP=1, MTIE=1, MIE=0 => no timer trap.
                8'd5: begin
                    csr_write(12'h304, 64'h80);
                    state = 8'd6;
                end
                8'd6: begin
                    csr_write(12'h300, 64'h0);
                    state = 8'd7;
                end
                8'd7: begin
                    check(!intr_flush_en && !intr_alu_intr);
                    state = 8'd8;
                end

                // Prepare direct-mode mtvec.
                8'd8: begin
                    csr_write(12'h305, 64'h8000_1003);
                    state = 8'd9;
                end

                // Case C/D: MTIP=1, MTIE=1, MIE=1 => timer trap and entry state.
                8'd9: begin
                    csr_write(12'h300, 64'h8);
                    state = 8'd10;
                end
                8'd10: begin
                    check(intr_flush_en);
                    check(intr_alu_intr);
                    check(intr_mcause == 64'h8000_0000_0000_0007);
                    check(intr_flush_addr == 64'h8000_1000);
                    state = 8'd11;
                end
                8'd11: begin
                    csr_read(12'h300);
                    state = 8'd12;
                end
                8'd12: begin
                    check(csr_rdata[3] == 1'b0);
                    check(csr_rdata[7] == 1'b1);
                    csr_read(12'h342);
                    state = 8'd13;
                end
                8'd13: begin
                    check(csr_rdata == 64'h8000_0000_0000_0007);
                    csr_write(12'h341, 64'h8000_0203);
                    intr_source = 3'b000;
                    state = 8'd14;
                end

                // Case E: mret restores MIE from MPIE, sets MPIE, and redirects to mepc.
                8'd14: begin
                    intr_mret = 1'b1;
                    state = 8'd15;
                end
                8'd15: begin
                    intr_mret = 1'b0;
                    state = 8'd16;
                end
                8'd16: begin
                    csr_read(12'h300);
                    state = 8'd17;
                end
                8'd17: begin
                    check(csr_rdata[3] == 1'b1);
                    check(csr_rdata[7] == 1'b1);
                    csr_write(12'h300, 64'h0);
                    state = 8'd18;
                end

                // Case F: timer source sets only mip.MTIP and clearing it clears mip.MTIP.
                8'd18: begin
                    intr_source = 3'b001;
                    state = 8'd19;
                end
                8'd19: begin
                    csr_read(12'h344);
                    state = 8'd20;
                end
                8'd20: begin
                    csr_read(12'h344);
                    state = 8'd21;
                end
                8'd21: begin
                    check(csr_rdata[7] == 1'b1);
                    check(csr_rdata[3] == 1'b0);
                    intr_source = 3'b000;
                    state = 8'd22;
                end
                8'd22: begin
                    csr_read(12'h344);
                    state = 8'd23;
                end
                8'd23: begin
                    csr_read(12'h344);
                    state = 8'd24;
                end
                8'd24: begin
                    check(csr_rdata[7] == 1'b0);
                    check(csr_rdata[3] == 1'b0);
                    state = 8'd25;
                end

                // Case G: software source sets only mip.MSIP and clearing it clears mip.MSIP.
                8'd25: begin
                    intr_source = 3'b010;
                    state = 8'd26;
                end
                8'd26: begin
                    csr_read(12'h344);
                    state = 8'd27;
                end
                8'd27: begin
                    csr_read(12'h344);
                    state = 8'd28;
                end
                8'd28: begin
                    check(csr_rdata[3] == 1'b1);
                    check(csr_rdata[7] == 1'b0);
                    intr_source = 3'b000;
                    state = 8'd29;
                end
                8'd29: begin
                    csr_read(12'h344);
                    state = 8'd30;
                end
                8'd30: begin
                    csr_read(12'h344);
                    state = 8'd31;
                end
                8'd31: begin
                    check(csr_rdata[3] == 1'b0);
                    check(csr_rdata[7] == 1'b0);
                    state = 8'd32;
                end

                // CLINT source: mtime >= mtimecmp sets MTIP and raising mtimecmp clears it.
                8'd32: begin
                    clt_req_vld = 1'b1;
                    clt_wen = 1'b1;
                    clt_addr = 64'h2000_4000;
                    clt_wdata = 64'h0;
                    state = 8'd33;
                end
                8'd33: begin
                    check(clt_mtip);
                    state = 8'd34;
                end
                8'd34: begin
                    clt_req_vld = 1'b1;
                    clt_wen = 1'b1;
                    clt_addr = 64'h2000_4000;
                    clt_wdata = 64'hffff_ffff_ffff_ffff;
                    state = 8'd35;
                end
                8'd35: begin
                    state = 8'd36;
                end
                8'd36: begin
                    check(!clt_mtip);
                    state = 8'd37;
                end

                // Case H: assert sources while MIE is low, then inspect before the next edge.
                8'd37: begin
                    csr_write(12'h304, 64'h888);
                    state = 8'd38;
                end
                8'd38: begin
                    csr_write(12'h300, 64'h0);
                    state = 8'd39;
                end
                8'd39: begin
                    intr_source = 3'b111;
                    state = 8'd40;
                end
                8'd40: begin
                    csr_write(12'h300, 64'h8);
                    state = 8'd41;
                end
                8'd41: begin
                    check(intr_flush_en);
                    check(intr_mcause == 64'h8000_0000_0000_000b);
                    intr_source = 3'b000;
                    csr_write(12'h300, 64'h0);
                    state = 8'd42;
                end
                8'd42: begin
                    intr_source = 3'b011;
                    state = 8'd43;
                end
                8'd43: begin
                    csr_write(12'h300, 64'h8);
                    state = 8'd44;
                end
                8'd44: begin
                    check(intr_flush_en);
                    check(intr_mcause == 64'h8000_0000_0000_0003);
                    intr_source = 3'b000;
                    done = 1'b1;
                end
                default: begin
                    fail = 1'b1;
                    done = 1'b1;
                    failed_state = state;
                end
            endcase
        end
    end
endmodule
