# A2 Cache C2 Summary

C2 exports the accepted D-cache sequence from reset, reconstructs PRE_ROI
state, and exactly calibrates the baseline 8 KiB cache against every recorded
RTL outcome. It then changes only capacity in software for a 4/8/16/32 KiB
sweep.

GOL128 shows capacity sensitivity, but 16 KiB yields only an estimated
1.003817x whole-workload speedup. GOL256, the larger decision workload, retains
4,080 misses and 4,080 writebacks at every tested capacity. Its estimated
cycles and 180 generations/s frequency remain 2,394,963 and 431.09334 MHz.
Combined with the C1 D-cache stall fraction of about 2.9%, the evidence does
not justify a Cache RTL P1 capacity change.

The counterfactual estimates assume similar miss/writeback penalty and are not
measured RTL cycles. No area or timing conclusion is made. Retirement remains
out of scope and NOT_QUALIFIED. I-cache DSE remains stopped after C1 found no
bottleneck evidence.

`CACHE_C2_TRACE_NONPERTURBING=YES`

`CACHE_REPLAY_BASELINE_CALIBRATION=PASS`

`ICACHE_CAPACITY_DSE_STATUS=STOPPED_AFTER_C1_NO_BOTTLENECK_EVIDENCE`

`CACHE_ARCHITECTURE_MODIFIED=NO`

`FUNCTIONAL_RTL_BEHAVIOR_MODIFIED=NO`
