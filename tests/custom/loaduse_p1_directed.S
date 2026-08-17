    .option norvc
    .section .text.start
    .globl _start

_start:
    la s0, loaduse_data

    ld t0, 8(s0)
    addi t1, t0, 1
    li t2, 0x1122334455667789
    bne t1, t2, fail

    lb t0, 0(s0)
    addi t1, t0, 1
    li t2, -127
    bne t1, t2, fail

    lbu t0, 0(s0)
    add t1, x0, t0
    li t2, 128
    bne t1, t2, fail

    lh t0, 2(s0)
    add t1, t0, t0
    li t2, -65534
    bne t1, t2, fail

    lhu t0, 2(s0)
    addi t1, t0, 0
    li t2, 32769
    bne t1, t2, fail

    lw t0, 4(s0)
    addi t1, t0, -1
    li t2, 0xffffffff80000000
    bne t1, t2, fail

    lwu t0, 4(s0)
    addi t1, t0, 1
    li t2, 0x80000002
    bne t1, t2, fail

    ld t0, 8(s0)
    add t1, x0, t0
    li t2, 0x1122334455667788
    bne t1, t2, fail

    ld t0, 8(s0)
    add t1, t0, t0
    li t2, 0x22446688aaccef10
    bne t1, t2, fail

    ld x0, 8(s0)
    addi t1, x0, 1
    li t2, 1
    bne t1, t2, fail

    ld t0, 8(s0)
    beq t0, x0, fail
    jal x0, branch_pass
    addi a0, x0, 1
branch_pass:

    ld t0, 24(s0)
    sd t0, 0(t0)
    la t1, store_target
    ld t2, 0(t1)
    bne t2, t0, fail

    ld t0, 8(s0)
    sd t0, 32(s0)
    ld t1, 32(s0)
    li t2, 0x1122334455667788
    bne t1, t2, fail

    ld t0, 8(s0)
    ld t1, 16(s0)
    li t2, 0x8877665544332211
    bne t0, t2, back_to_back_second
    jal x0, fail
back_to_back_second:
    li t2, 0x1122334455667788
    bne t0, t2, fail
    li t2, 0x8877665544332211
    bne t1, t2, fail

    la s1, dirty_line0
    li t0, 1
    sd t0, 0(s1)
    ld t1, 0(s1)
    addi t2, t1, 1
    li t3, 2
    bne t2, t3, fail

    la s1, dirty_line1
    li t0, 2
    sd t0, 0(s1)
    ld t1, 0(s1)
    addi t2, t1, 1
    li t3, 3
    bne t2, t3, fail

    la s1, dirty_line2
    li t0, 3
    sd t0, 0(s1)
    ld t1, 0(s1)
    addi t2, t1, 1
    li t3, 4
    bne t2, t3, fail

    la s1, dirty_line3
    li t0, 4
    sd t0, 0(s1)
    ld t1, 0(s1)
    addi t2, t1, 1
    li t3, 5
    bne t2, t3, fail

    la s1, dirty_line4
    li t0, 5
    sd t0, 0(s1)
    ld t1, 0(s1)
    addi t2, t1, 1
    li t3, 6
    bne t2, t3, fail

    li a0, 0
    ebreak

fail:
    li a0, 1
    ebreak

    .section .data
    .balign 8
loaduse_data:
    .byte 0x80, 0x00
    .half 0x8001
    .word 0x80000001
    .dword 0x1122334455667788
    .dword 0x8877665544332211
    .dword store_target
    .dword 0
store_target:
    .dword 0

    .section .data.dirty0
dirty_line0: .dword 0
    .section .data.dirty1
dirty_line1: .dword 0
    .section .data.dirty2
dirty_line2: .dword 0
    .section .data.dirty3
dirty_line3: .dword 0
    .section .data.dirty4
dirty_line4: .dword 0
