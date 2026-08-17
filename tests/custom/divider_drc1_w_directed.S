    .option norvc
    .section .text.start
    .globl _start

.macro CHECK op, lhs, rhs, expected
    li t0, \lhs
    li t1, \rhs
    \op t2, t0, t1
    addi t3, t2, 0
    li t4, \expected
    bne t3, t4, fail
.endm

_start:
    li s0, 1
    CHECK divw, 7, 3, 2
    CHECK divw, -7, 3, -2
    CHECK divw, 7, -3, -2
    CHECK divw, -7, -3, 2
    CHECK divw, 5, 11, 0
    CHECK divw, 0xffffffff80000000, -1, 0xffffffff80000000
    CHECK divw, 0x0000000080000000, 0, -1

    CHECK divuw, 0x00000000ffffffff, 2, 0x000000007fffffff
    CHECK divuw, 5, 11, 0
    CHECK divuw, 0x00000000ffffffff, 0, -1

    CHECK remw, 7, 3, 1
    CHECK remw, -7, 3, -1
    CHECK remw, 7, -3, 1
    CHECK remw, -7, -3, -1
    CHECK remw, 5, 11, 5
    CHECK remw, 0xffffffff80000000, -1, 0
    CHECK remw, -7, 0, -7

    CHECK remuw, 0x00000000ffffffff, 2, 1
    CHECK remuw, 5, 11, 5
    CHECK remuw, 0x00000000ffffffff, 0, -1

    li t0, -100
    li t1, 7
    divw t2, t0, t1
    addi t3, t2, 14
    bne t3, x0, fail
    li t0, 100
    li t1, 9
    divuw t2, t0, t1
    addi t3, t2, -11
    bne t3, x0, fail

    li a0, 0
    ebreak

fail:
    li a0, 1
    ebreak
