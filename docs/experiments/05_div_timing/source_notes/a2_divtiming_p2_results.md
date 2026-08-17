# A2 Divider Timing P2 Results

## Provenance And Scope

- Frozen P1 base commit: `4858651e70bd41fb9cc789a4b09a3f0de624d46a`
- Frozen P1 base tree: `b289a9a430ffb387d268b43bd08cc08f84022102`
- Branch: `opt/a2-loaduse-p1-divtiming-p2`
- Optimization: `DRC1_COMPLETION_TIME_SIGNED_QUOTIENT_STORAGE`
- Primary timing target: `DIV_RESULT_TO_ID_ALU_RS1_OPERAND_REGISTER`

The only synthesizable RTL change is in
`rtl/vsrc/exu/rv64im_core_div.sv`. It moves signed quotient correction to the
normal iterative completion update of `res_reg`. No pipeline stage, register,
interface, divider iteration, forwarding rule, stall rule, Load-use P1 logic,
cache logic, or SRAM logic changes.

## Completion Semantics

Before P2, `res_reg` held an iteratively constructed unsigned quotient
magnitude, and the normal quotient output applied a conditional 64-bit
two's-complement operation after that register. In P2, ordinary iterative
updates remain unsigned. On the edge selected by
`busy && !div_ready && div_done && !fast_div_r`, the final quotient bit is
formed and signed correction is applied once while writing `res_reg`.

`div_done` identifies the edge that performs the last quotient-bit update;
that same edge raises `div_ready`. Therefore subsequent normal quotient reads
observe the architecturally signed value directly. While a ready result is
held by downstream stall, `data_upd_en` is false and the corrected value is
retained. The fast-div constant result path and remainder path are unchanged.
Reset behavior and request/ack timing are unchanged.

## Divider Equivalence Gate

`scripts/run_divider_drc1_directed.sh` built standalone P1 and P2 divider
models and compared 854 cases byte-for-byte, including output values and ack
cycles. Coverage includes signed and unsigned quotient/remainder operations,
fixed boundary operands, 512 deterministic random cases, division by zero,
signed overflow, magnitude relations, fast completion, back-to-back requests,
and a ready result held for three stall cycles. Both CSV files contain 855
lines including the header.

The 64-bit DIV/DIVU/REM/REMU integration image passed DiffTest with a good trap
on both P1 and P2. Immediate dependent `addi` consumers after DIV and DIVU
also passed. DIVW/DIVUW/REMW/REMUW and their dependent consumers passed a
self-checking integration image with a good trap on both revisions.

The patched local NEMU reference is unsuitable for special-case and W-form
oracle coverage: it host-crashes with `FPE` for divide-by-zero and signed
overflow, and its signed W-form result is incorrect for tested cases. Those
classes are consequently proven by the standalone P1-versus-P2 bit/cycle
comparison and the no-DiffTest W-form integration test. Normal project
regression still uses the patched reference and passes.

## Functional And Cycle Gates

- `git diff --check`: PASS
- Verilator lint: PASS
- `make doctor`, `make build`, dummy plus DiffTest, and `make smoke`: PASS
- CPU tests: 33/33 PASS
- Klib tests: 33/33 PASS
- Dedicated klib unit tests: 8/8 PASS
- MicroBench, AM hello, AM RTC, timer128, and directed interrupts: PASS
- I-cache 64-set directed and Load-use P1 directed tests: PASS
- DiffTest fatal, mismatch, bad-trap, abort, assertion, and non-convergence
  markers: 0

| Workload | P1 cycles | P2 cycles | Checksum | Exact match |
| --- | ---: | ---: | ---: | --- |
| MicroBench FIB | 11978 | 11978 | n/a | YES |
| CPU bubble sort | 1672 | 1672 | n/a | YES |
| GOL128 | 463868 | 463868 | 3844 | YES |
| GOL256 | 1880884 | 1880884 | 15876 | YES |

ROI and counter sampled cycles match exactly, all dependency outcomes resolve,
and the performance runner exits successfully.

## Reproduction

```sh
NEMU_REF_SO=${LOCAL_HOME}/ysyx-workbench/nemu/build/riscv64-nemu-ref-patched.so \
  bash scripts/run_divider_drc1_directed.sh
make doctor
make build
make run TEST=dummy
make smoke
make regress
bash scripts/run_icache_64set_directed.sh
bash scripts/run_loaduse_p1_directed.sh
NEMU_REF_SO=${LOCAL_HOME}/ysyx-workbench/nemu/build/riscv64-nemu-ref-patched.so \
AM_KERNELS_DIR=${LOCAL_HOME}/ysyx-workbench/am-kernels \
GOL_WORKLOAD_DIR=${LOCAL_HOME}/rv64im-workload-scratch/profiling/gol_scaling_01 \
  bash scripts/run_loaduse_p1_performance.sh
```

No synthesis, PrimeTime, setup/hold analysis, or area measurement was run in
this Gate. These functional results do not establish that timing is fixed.
Fresh RFIC 500 MHz synthesis and setup/hold/area characterization is the next
acceptance step.
