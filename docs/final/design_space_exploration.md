# Design-space exploration

| Candidate | Motivation | Measurement / experiment | Result | Cost or risk | Decision | Reason |
|---|---|---|---|---|---|---|
| Branch predictor capacity | Reduce recovery loss | Replay at 512/1024/2048 entries | FIB 602/603/603 errors; Bubble 104/104/104 | Predictor storage and verification | Rejected | Capacity scaling was flat |
| Cache capacity | Reduce D$ miss stalls | C0/C1 counters; exact 4/8/16/32 KiB PLRU replay | GOL256 4080 misses at every capacity | SRAM/area and cache requalification | Rejected | Main workload gained no miss reduction |
| Load-use bypass | Remove dominant dependency episodes | Exclusive attribution and one-cycle counterfactual | 1.273318x predicted, 1.273318x measured GOL256 | Hit qualification and forwarding verification | Accepted | Strong, accurately predicted benefit |
| `FEC1_DIV_QUALIFIED_DIRECT_FORWARDING_ROUTE` | Shorten DIV→ID path | RTL cone audit | Plausible but specialized routing | Additional forwarding qualification | Rejected | DRC1 offered a simpler cycle-equivalent root fix |
| `FEC2_FACTORED_DIV_REM_AND_GENERAL_EX_RESULT_SELECTION` | Factor general result selection | RTL cone audit | Broader mux refactor | Wider functional/timing blast radius | Rejected | Higher integration risk than DRC1 |
| `DRC1_COMPLETION_TIME_SIGNED_QUOTIENT_STORAGE` | Remove sign selection from completion forwarding | 854 cases, P1/P2 bit-and-cycle equivalence, fresh STA | Functional equivalence; 500 MHz closure | Local divider state/result change | Accepted | Preserved cycle behavior and removed target cone |
| Disable same-cycle DIV forwarding | Guaranteed cone break | Microarchitectural fallback analysis | Nominal +1 cycle for immediate dependent consumer; target DIV count 0 | Architectural performance change | Fallback only | Unneeded because DRC1 closed timing cycle-equivalently |

Rejected experiments are published because they constrain future work: the
models prevented attractive but unsupported capacity changes.
