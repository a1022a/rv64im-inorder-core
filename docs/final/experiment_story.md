# Experiment story

The project began by closing baseline function and an SRAM-based,
synthesis-ready cache implementation. A deterministic Game of Life workload
then supplied scalable, checksum-qualified performance pressure. Explicit ROI
and retirement semantics made exclusive attribution possible.

Branch replay was the first candidate study. Recovery was visible, but
512/1024/2048-entry sweeps were flat, so branch capacity was stopped. Cache
C0/C1 instrumentation next showed no I-cache case and only weak initial D-cache
evidence. C2 replay reproduced the RTL's four-way tree-PLRU using accepted
accesses and PRE_ROI warmup. GOL128 responded to larger capacity, proving model
sensitivity, but GOL256 remained at 4080 misses from 4 through 32 KiB. Cache
capacity was stopped without spending SRAM or area.

Exact dependency attribution then revealed the decisive opportunity: 516,128
GOL256 load-use cycles, 514,080 of them load hits. A one-cycle counterfactual
predicted about 1.2733x. P1 implemented a carefully qualified load-hit-use
bypass and measured 2,394,963→1,880,884 cycles, matching prediction to one
cycle while preserving checksums and miss/flush semantics.

Timing feasibility became the next constraint. Fresh 500 MHz P1 synthesis and
STA missed setup by 1.319 ps, but a direct bypass-path probe passed and was not
in the top 20. RTL/path audit traced the failure to DIV-to-ID forwarding.
Alternatives included FEC1, FEC2, DRC1, and a one-cycle dependency-bubble
fallback. DRC1 was selected because it stores the signed quotient at completion
and retains cycle behavior.

P2 passed functional qualification, including 854 divider cases and P1/P2
cycle equivalence, but DC PRESTO rejected a use-before-declaration construct as
VER-956. P2R1 made only the declaration-order repair. Fresh 500 MHz DC and PT
then passed setup and hold; the old DIV-to-ID path disappeared from the top 20
and the critical path migrated to the CSR cycle counter. With a thin positive
setup margin and the targeted cone removed, P3 was stopped.
