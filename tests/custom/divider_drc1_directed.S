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
    CHECK div, 0, 1, 0
    CHECK div, 7, 3, 2
    CHECK div, -7, 3, -2
    CHECK div, 7, -3, -2
    CHECK div, -7, -3, 2
    CHECK div, 5, 11, 0
    CHECK div, 11, 11, 1
    CHECK div, 12, 11, 1

    CHECK divu, 0xffffffffffffffff, 2, 0x7fffffffffffffff
    CHECK divu, 5, 11, 0
    CHECK divu, 11, 11, 1
    CHECK divu, 12, 11, 1

    CHECK rem, 7, 3, 1
    CHECK rem, -7, 3, -1
    CHECK rem, 7, -3, 1
    CHECK rem, -7, -3, -1
    CHECK rem, 5, 11, 5

    CHECK remu, 0xffffffffffffffff, 2, 1
    CHECK remu, 5, 11, 5

    li t0, -100
    li t1, 7
    div t2, t0, t1
    addi t3, t2, 14
    bne t3, x0, fail
    li t0, 100
    li t1, 9
    divu t2, t0, t1
    addi t3, t2, -11
    bne t3, x0, fail

    li a0, 0
    ebreak

fail:
    li a0, 1
    ebreak
