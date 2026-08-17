# 02 — Cache C0/C1 and C2 DSE

C0/C1 qualified I$/D$ observation and established that I-cache evidence was
absent and initial D-cache bottleneck evidence was weak. GOL256 recorded
1,792,893 I-accesses, 8 I-misses, 64 I-stall cycles, 645,160 D-accesses, 4,080
D-misses (about 0.6324%), 32,648 refill-stall cycles, 36,720 writeback-stall
cycles, 69,368 total D-stall cycles, and 4,080 writebacks.

C2 replayed accepted D-cache accesses from reset with PRE_ROI warmup and exact
four-way tree-PLRU. Misses for 4/8/16/32 KiB were 0/0/0/0 (FIB), 3/3/3/3
(Bubble), 1016/1016/884/0 (GOL128), and 4080/4080/4080/4080 (GOL256). GOL128
proves that the model can observe a real capacity benefit; the main GOL256
workload does not benefit in the explored range.

Decision: `CACHE_P1_JUSTIFIED=NO`, `STOP_CACHE_DSE`, `RTL_CHANGE=NONE`. The
model prevented an unjustified area/SRAM architecture change.

Source class: cache modeling, C0/C1 commit
`68988e93f3be248a10a31819ee56084437ed4bd1`, C2 commit
`82172832eb28517a7a7c88b0d06b37be636ad77a`.
