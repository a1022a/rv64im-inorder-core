# A2 DIV-to-ID Timing Audit Summary

## Conclusion

The exact P1 500 MHz setup failure maps from the divider's unsigned quotient
state through conditional 64-bit signed correction, result selection, and
same-cycle EX-to-ID forwarding into the RS1 operand register. The divider
final correction is the primary root cause; general EX selection plus the ID
forwarding priority structure are secondary contributors.

`DIV_RESULT_DIRECT_TO_FORWARDING=NO`. There are five conceptual selection
stages after normal quotient correction. This is an RTL accounting statement,
not mapped cell depth.

The preferred P2 experiment is DRC1, completion-time signed quotient storage
in the existing divider result register. It is expected to preserve function,
cycles, divider latency, forwarding behavior, and Load-use P1, but none of
those expectations is claimed proven by this analysis-only Gate.

## Dynamic risk method

The analysis branch adds only simulation-side counters to
`sim/csrc/dependency_observer.cpp`. A DIV-family instruction is recognized by
RV64/RV64W register opcode, `funct7=1`, and `funct3>=4`. Completion is sampled
at the falling edge of the existing divider-stall observation while the EX
producer remains the DIV-family instruction. The held ID instruction is
decoded with the existing operand-use rules and counted when a real RS1 or RS2
matches the nonzero producer destination.

This observes potential one-cycle fallback exposure; it does not alter RTL.
Qualified workload counts and cycle ratios are recorded after the profiling
script's ROI, trap/termination, checksum, and cycle-accounting gates pass.
As a sensitivity check, the existing `div` CPU test completed with DiffTest
good trap and the observer counted 100 DIV-family completions. This confirms
that zero counts in a measured workload are distinguishable from a dead
counter; the test itself contains no immediate DIV-result consumer episodes.

## Qualified dynamic results

`DIV_DYNAMIC_PROFILE_STATUS=QUALIFIED`

| Workload | ROI cycles | DIV count | Immediate DIV dependency episodes | Estimated fallback extra cycles | Estimated impact |
| --- | ---: | ---: | ---: | ---: | ---: |
| FIB | 11978 | 0 | 0 | 0 | 0.000000% |
| Bubble sort | 1672 | 0 | 0 | 0 | 0.000000% |
| GOL128 | 463868 | 0 | 0 | 0 | 0.000000% |
| GOL256 | 1880884 | 0 | 0 | 0 | 0.000000% |

FIB and bubble sort reached DiffTest good trap. GOL128 and GOL256 passed
controlled termination, cache counter invariants, cycle accounting, and
checksums `3844` and `15876`. All dependency JSON records have valid ROI,
zero unresolved load outcomes, and exit status zero. The zero estimated
fallback cost applies only to these measured workload ROIs; it is not a claim
that general software has no DIV dependency exposure.

## Future P2 acceptance criteria

For the cycle-equivalent DRC1 experiment:

- Full regression PASS with no DiffTest mismatch, bad trap, abort, assertion,
  or non-convergence marker.
- Divider directed, load-use directed, and cache directed tests PASS.
- FIB remains exactly `11978` cycles.
- Bubble sort remains exactly `1672` cycles.
- GOL128 remains exactly `463868` cycles with checksum `3844`.
- GOL256 remains exactly `1880884` cycles with checksum `15876`.
- Fresh 500 MHz synthesis and PrimeTime setup PASS with `TNS=0` and zero
  violations.
- Exact-netlist fast/min hold PASS.
- Area delta is reported.
- Divider result equivalence explicitly covers DIV, DIVU, REM, REMU and all W
  forms, signed overflow, division by zero, magnitude-less-than-divisor fast
  completion, final quotient-bit timing, a ready result held by downstream
  stall, reset/flush, and back-to-back requests.

If MAF1 is eventually used instead, exact performance equality is not an
acceptance requirement. Its observed cycle delta and workload impact must be
measured and documented, while all functional and RFIC gates remain required.

## Gate boundaries

- Synthesizable RTL modified: NO
- Divider function or latency modified: NO
- Pipeline stall or forwarding behavior modified: NO
- Load-use P1 modified: NO
- RFIC synthesis/STA performed: NO
- Future P2 optimization branch created: NO
