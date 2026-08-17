# Architecture A2 Functional Closure

完整回归已人工确认通过：CPU tests 33/33、CPU+klib tests 33/33、klib unit
tests 8/8、MicroBench、AM hello、AM RTC、timer interrupt/mret 和 directed
interrupt tests 均为 PASS；DiffTest fatal、bad trap、abort、assertion failure
与 non-convergence 计数均为 0，`make regress` 退出码为 0。

I-cache 专用定向验证动态执行五条相隔 `0x400` 的函数 instruction line。仿真
结束时从实际 I-cache tag/valid/way 状态读取到 set 32 中 3 条、set 0 中 2 条，
而旧的 32-set index 会将全部 5 条映射到 set 0 并超过 4-way 容量。NEMU
reference 已加载，DiffTest 保持 active，程序以 GOOD TRAP 正常结束。

FULL_REGRESS=PASS
CPU_TESTS=33/33 PASS
CPU_KLIB_TESTS=33/33 PASS
KLIB_UNIT_TESTS=8/8 PASS
MICROBENCH=PASS
AM_HELLO=PASS
AM_RTC=PASS
TIMER_INTERRUPT=PASS
DIRECTED_INTERRUPT_TESTS=PASS

ICACHE_64SET_DIRECTED=PASS

DIFFTEST_FATAL_COUNT=0
BAD_TRAP_COUNT=0
ASSERTION_FAILURE_COUNT=0
NON_CONVERGENCE_COUNT=0

GENERIC_FULL_REGRESSION=PASS
A2_FUNCTIONAL_CLOSURE=PASS
READY_FOR_EDA_SYNTHESIS=YES
