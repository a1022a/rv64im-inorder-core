# Verification

## Functional gates

The final integration reruns `make doctor`, `make build`, `make run TEST=dummy`,
`make smoke`, `make regress`, the 64-set I-cache directed test, the load-use P1
directed test, the DRC1 divider test, and the P1 performance runner.

The retained full matrix comprises 33/33 CPU tests, 33/33 CPU tests linked with
klib, 8/8 klib unit tests, MicroBench, AM hello, AM RTC, timer128 interrupt and
`mret`, with no DiffTest fatal marker, bad trap, abort, assertion failure, or
non-convergence marker. Machine-readable status is in
`results/public/verification/summary.csv`.

## Optimization-specific qualification

Load-use directed tests qualify accepted request, D-cache hit, formatted LSU
response, dependent operands, and unchanged miss/flush behavior. Final measured
cycles must be exactly FIB 11,978; Bubble 1,672; GOL128 463,868 with checksum
3844; and GOL256 1,880,884 with checksum 15876.

DRC1 uses 854 directed cases and compares P1/P2 result bits and acknowledgment
cycles. Coverage includes all RV64 and W-form DIV/REM operations, divide by
zero, signed overflow, randomized inputs, back-to-back requests, stall hold,
and immediate dependent consumers.

## Reference limitation

The patched NEMU reference can raise a host floating-point exception on
selected divide-by-zero/signed-overflow cases and is unreliable as the oracle
for selected signed W forms. Those cases use standalone expected-value checks,
P1/P2 bit-and-cycle equivalence, and W-form self-checking integration. NEMU is
not claimed to cover every divider corner case.

## ASIC evidence

Fresh P2R1 DC/PT analysis at a 2.0 ns target reports setup WNS +0.000097 ns,
TNS 0, zero violations; hold WNS +0.037408 ns, TNS 0, zero violations. This is
pre-layout synthesized front-end evidence only. See `docs/asic/` for method and
scope.
