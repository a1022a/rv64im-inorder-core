# A2 Load-Use Phase 8R Summary

The RTL audit, semantics, directed qualification, exact old-attribution
calibration, and four authorized workload profiles pass. The monitor changes
only simulation observability and does not modify the synthesizable datapath or
architectural behavior.

The evidence separates two mechanisms hidden by the old label. FIB's entire
1.87% dependency share is multiply-related. Bubble-sort and GOL are true
load-use dominated; GOL256 has 514,080 one-cycle hit-use episodes, a 21.465%
ROI share, concentrated in eight static PC pairs. The conservative one-cycle
hit-use sensitivity is 1.273318x and lowers the 180 generation/s frequency
sensitivity from 431.093340 to 338.558940 MHz.

`LOAD_USE_PERFORMANCE_OPPORTUNITY=STRONG`

`LOAD_USE_P1_PERFORMANCE_JUSTIFIED=YES`

`NEXT_STEP_RFIC_TIMING_AUDIT=REQUIRED`

This decision authorizes only a later read-only RFIC timing-cone audit. It does
not authorize a bypass, forwarding mux, cache/SRAM timing change, synthesis, or
PrimeTime in this phase.
