# A2 Dependency Counter Semantics

The profiler is simulation-only. The RTL additions expose existing
combinational state under the existing performance-model interface; all shadow
state and instruction classification live in the host observer.

`DEPENDENCY_STALL_CYCLE` is a sampled cycle for which `idu_pipe_stall` wins the
frozen exclusive priority: no D-cache total stall, divider stall, or branch
recovery is active. The sum of all fine-grained classes must equal the old
exclusive dependency count exactly.

`DEPENDENCY_STALL_EPISODE` is one maximal contiguous run of exclusive dependency
cycles. A three-cycle run is one episode and three cycles, never three events.
The same definition applies to load-use, load-hit-use, load-miss-related,
multiply, and other subsets.

The host decoder qualifies actual GPR operand use for RV64IM. It excludes x0,
immediate `rs2` fields, U/J encodings, and CSR-immediate zimm. Source is RS1,
RS2, BOTH, or FALSE. Architectural LOAD and MUL producer classes come from the
actual EX instruction, not the misleading RTL signal name.

A true load-use episode is correlated to its accepted D-cache load by aligned
32-bit address in program order. The accepted access's qualified RTL hit/miss
outcome labels the episode. Miss wait cycles remain in the higher-priority
D-cache category and are not added again. `LOAD_MISS_RELATED_DEPENDENCY_CYCLES`
therefore means dependency bubbles whose producer access subsequently/currently
allocates a miss, not cache wait cycles.

ALU RAW, CSR dependency, and DIV dependency counters are qualified zero because
directed testing proves forwarding or separate divider-stall handling. False
raw interlocks are reported as other, not load-use. Retirement, IPC, and MPKI
remain `NOT_QUALIFIED`.
