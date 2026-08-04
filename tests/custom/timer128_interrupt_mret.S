    .section .text
    .globl _start

_start:
    li s0, 0
    la sp, stack_top
    la t0, trap_entry
    csrw mtvec, t0

    li t0, 0x20004000
    li t1, 128
    sd t1, 0(t0)

    li t0, 0x8
    csrs mstatus, t0

wait_irq:
    addi s1, s1, 1
    li t2, 100000
    blt s1, t2, wait_irq
    li a0, 1
    ebreak

trap_entry:
    csrr t0, mcause
    li t1, 0x8000000000000007
    bne t0, t1, fail

    li t0, 0x20004000
    li t1, -1
    sd t1, 0(t0)

    li s0, 1
    la t0, after_mret
    csrw mepc, t0
    mret

after_mret:
    li t0, 1
    bne s0, t0, fail
    li a0, 0
    ebreak

fail:
    li a0, 1
    ebreak

    .section .bss
    .align 12
stack:
    .space 4096
stack_top:
