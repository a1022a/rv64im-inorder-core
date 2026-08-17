    .option norvc
    .section .text.start
    .globl _start

_start:
    lui t0, 0x80001

    .globl perf_roi_start
perf_roi_start:
    nop

    .globl perf_roi_lead0
perf_roi_lead0:
    nop
    .globl perf_roi_lead1
perf_roi_lead1:
    nop
    .globl perf_roi_lead2
perf_roi_lead2:
    nop
    .globl perf_roi_lead3
perf_roi_lead3:
    nop
    .globl perf_roi_lead4
perf_roi_lead4:
    nop
    .globl perf_roi_lead5
perf_roi_lead5:
    nop

    .globl perf_roi_addi
perf_roi_addi:
    addi s0, x0, 7
    .globl perf_roi_forward
perf_roi_forward:
    addi s0, s0, 1
    .globl perf_roi_store
perf_roi_store:
    sd s0, 0(t0)
    .globl perf_roi_load
perf_roi_load:
    ld s1, 0(t0)
    .globl perf_roi_load_use
perf_roi_load_use:
    addi s2, s1, 1
    .globl perf_roi_div
perf_roi_div:
    div s3, s2, s0
    .globl perf_roi_branch_not_taken
perf_roi_branch_not_taken:
    beq s3, x0, perf_roi_fail
    .globl perf_roi_branch_taken
perf_roi_branch_taken:
    beq s3, s3, perf_roi_taken
    .globl perf_roi_wrong_path
perf_roi_wrong_path:
    addi a0, x0, 1

perf_roi_taken:
    .globl perf_roi_jal
perf_roi_jal:
    jal x0, perf_roi_jal_target
    .globl perf_roi_jal_wrong_path
perf_roi_jal_wrong_path:
    addi a0, x0, 2

perf_roi_jal_target:
    .globl perf_roi_jalr_base
perf_roi_jalr_base:
    auipc t6, 0
    .globl perf_roi_jalr_addr
perf_roi_jalr_addr:
    addi t6, t6, 16
    .globl perf_roi_jalr
perf_roi_jalr:
    jalr x0, 0(t6)
    .globl perf_roi_jalr_wrong_path
perf_roi_jalr_wrong_path:
    addi a0, x0, 3

perf_roi_jalr_target:
    .globl perf_roi_csr
perf_roi_csr:
    csrr s4, mstatus
    .globl perf_roi_result
perf_roi_result:
    addi a0, x0, 0

    .globl perf_roi_drain0
perf_roi_drain0:
    nop
    .globl perf_roi_drain1
perf_roi_drain1:
    nop
    .globl perf_roi_drain2
perf_roi_drain2:
    nop
    .globl perf_roi_drain3
perf_roi_drain3:
    nop
    .globl perf_roi_drain4
perf_roi_drain4:
    nop

    .globl perf_roi_end
perf_roi_end:
    nop
    ebreak

perf_roi_fail:
    addi a0, x0, 1
    ebreak
