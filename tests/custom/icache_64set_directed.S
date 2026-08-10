    .option norvc
    .section .text.start
    .globl _start

_start:
    li s0, 0
    call icache_line_0
    call icache_line_1
    call icache_line_2
    call icache_line_3
    call icache_line_4
    li t0, 5
    bne s0, t0, fail
    li a0, 0
    ebreak

fail:
    li a0, 1
    ebreak

    .section .text.icache_line_0
    .globl icache_line_0
icache_line_0:
    addi s0, s0, 1
    ret

    .section .text.icache_line_1
    .globl icache_line_1
icache_line_1:
    addi s0, s0, 1
    ret

    .section .text.icache_line_2
    .globl icache_line_2
icache_line_2:
    addi s0, s0, 1
    ret

    .section .text.icache_line_3
    .globl icache_line_3
icache_line_3:
    addi s0, s0, 1
    ret

    .section .text.icache_line_4
    .globl icache_line_4
icache_line_4:
    addi s0, s0, 1
    ret
