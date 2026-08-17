# 03 — Load-use revisit and counterfactual

Episode attribution found: FIB 224 dependency cycles, zero load-use, and 224
MUL; Bubble 190 dependency/load-use cycles and 188 load-hit; GOL128 127,008
dependency/load-use and 126,496 load-hit; GOL256 ROI 2,394,963 with 516,128
dependency/load-use, 514,080 load-hit, and 2,048 miss-related cycles. GOL256's
dependency fraction is about 21.55%.

Perfect-dependency/perfect-load-use and one-cycle load-hit-use counterfactuals
were evaluated. The latter predicted speedups of 1.000000x, 1.112440x,
1.272699x, and 1.273318x for FIB, Bubble, GOL128, and GOL256.

Decision: `LOAD_USE_PERFORMANCE_OPPORTUNITY=STRONG` and
`LOAD_USE_P1_PERFORMANCE_JUSTIFIED=YES`.

Source class: load-use modeling, frozen commit
`a3386e568c42f46568170626f0e774441fd21d91`.
