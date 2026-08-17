# 04 — Load-use P1

P1 implements `ONE_CYCLE_LOAD_HIT_USE_BYPASS`. Qualification requires an
accepted request, valid D-cache tag hit, formatted LSU response, and matching
dependent EX operands. It adds zero synthesizable registers; miss and flush
behavior are unchanged.

Measured results: FIB 11,978→11,978; Bubble 1,860→1,672 (1.112440x); GOL128
590,363→463,868 (1.272696x, checksum 3844); GOL256
2,394,963→1,880,884 (1.273318x, checksum 15876). Required frequency for 180
GPS fell from 431.093340 to 338.559120 MHz. Prediction differed from measurement
by one cycle on each GOL case.

Source class: accepted P1, frozen commit
`4858651e70bd41fb9cc789a4b09a3f0de624d46a`.
