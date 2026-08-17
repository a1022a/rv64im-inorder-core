# A2 DIV Timing Candidate Comparison

## Comparison

| Candidate | Class | Cycle equivalent expected | Scope | Risk | Directness to measured path | Preference |
| --- | --- | --- | --- | --- | --- | --- |
| FEC2 | General result expression refactor | Yes | Tiny | Low | Weak; downstream only | Not preferred |
| FEC1 | Dedicated DIV-to-forwarding route | Yes | Medium | Moderate | Partial; correction remains | Not preferred |
| DRC1 | Completion-time signed quotient storage | Yes | Small | Moderate | Strong; removes measured post-launch carry cone | Preferred |
| DRC2 | Explicit prefix correction | Yes | Medium | Moderate | Strong but technology-sensitive | Not preferred |
| MAF1 | Disable same-cycle DIV forwarding for a matching consumer | No | Medium | Moderate | Cuts the complete DIV-to-ID path | Fallback only |

Exactly one future candidate is preferred: DRC1.

## Microarchitectural fallback

- `CANDIDATE_ID=MAF1`
- `DESCRIPTION=When a just-completed DIV-family EX producer matches an actual ID source operand, retain the consumer for one additional cycle and inject a bubble so it uses the following MEM forwarding opportunity instead of same-cycle EX forwarding.`
- `RTL_FILES_AFFECTED=rtl/vsrc/idu/rv64im_core_regfile.sv; rtl/vsrc/idu/rv64im_core_idu.sv; rtl/vsrc/core/rv64im_core_core.sv`
- `LOGIC_CONE_AFFECTED=DIV-specific dependency qualification and ID pipeline control; removes DIV result from same-cycle ID capture timing requirement`
- `FUNCTIONALLY_EQUIVALENT_EXPECTED=YES`
- `CYCLE_BEHAVIOR_CHANGED=YES`
- `NEW_REGISTER_REQUIRED=NO`
- `ESTIMATED_SCOPE=MEDIUM`
- `TIMING_RATIONALE=Prevents a matching ID consumer from capturing the acknowledged DIV result directly from EX, cutting the full measured register-to-register path.`
- `CORRECTNESS_RISK=MODERATE`

`MICROARCHITECTURAL_FALLBACK=DISABLE_SAME_CYCLE_DIV_TO_MATCHING_ID_FORWARDING_WITH_ONE_DEPENDENCY_BUBBLE`

Nominal behavior would be exactly one added cycle for an immediately dependent
consumer, because the same result becomes available from the existing MEM
forwarding source on the next cycle. Unrelated instructions would not be
stalled by a correctly qualified RAW check. The divider iteration count,
producer latency, and independent-instruction divider throughput would not
change; only the dependent consumer issue/capture time changes. Coincident
downstream stalls could mask the nominal penalty, so future implementation
must measure rather than assume aggregate cycle deltas.

MAF1 is not cycle-equivalent and is considered only if equivalent result-logic
cleanup fails timing closure.

## Preferred candidate

- `PREFERRED_P2_CANDIDATE=DRC1_COMPLETION_TIME_SIGNED_QUOTIENT_STORAGE`
- `PREFERRED_P2_CLASS=FUNCTION_AND_CYCLE_EQUIVALENT_DIVIDER_FINAL_RESULT_CLEANUP`
- `FUNCTIONAL_BEHAVIOR_CHANGED_EXPECTED=NO`
- `CYCLE_BEHAVIOR_CHANGED_EXPECTED=NO`
- `DIV_LATENCY_CHANGED_EXPECTED=NO`
- `LOADUSE_P1_CHANGED_EXPECTED=NO`
- `EXPECTED_RTL_FILES=rtl/vsrc/exu/rv64im_core_div.sv`
- `WHY_THIS_IS_MINIMAL=It is confined to one divider file, reuses res_reg and the existing completion boundary, and requires no new register or interface.`
- `WHY_THIS_CAN_TARGET_THE_MEASURED_PATH=The exact P1 path launches from res_reg[0], and DRC1 removes the normal 64-bit signed quotient correction from the combinational cone between that register and the ID operand register.`

## Decision

- `DIV_ID_TIMING_CLEANUP_OPPORTUNITY=STRONG`
- `DIV_ID_P2_EXPERIMENT_JUSTIFIED=YES`

The decision is based on structural targeting, not merely on the 1.319 ps
setup miss. DRC1 is one-file and directly changes the measured cone while
preserving the intended architecture. Its timing success and equivalence are
future experiment questions.

If authorized after review:

- Future branch: `opt/a2-loaduse-p1-divtiming-p2`
- Future worktree: `${LOCAL_HOME}/ysyx-workbench/rv64im-inorder-core-loaduse-p1-divtiming-p2`
- Future base: `4858651e70bd41fb9cc789a4b09a3f0de624d46a`

This audit does not create that branch or worktree.
