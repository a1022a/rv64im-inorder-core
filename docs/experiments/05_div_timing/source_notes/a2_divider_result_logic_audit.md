# A2 Divider Result Logic Audit

## `res_reg` content

`res_reg` is initialized to zero and, while the divider is busy, shifts left
one bit per iterative step. The appended bit is `~add_sign`, the quotient bit
from the unsigned magnitude comparison/subtraction. It therefore holds
iteratively constructed unsigned quotient magnitude bits.

It does not hold the final signed DIV result and it does not hold a remainder.
The remainder has a separate `rem_reg` path.

## Logic after `res_reg`

The following work remains combinationally downstream of `res_reg`:

1. Signed quotient correction: when `op1_signed ^ op2_signed`, compute
   `~res_reg + 1`.
2. Fast-div selection: choose either the corrected quotient or a constant
   quotient. The constant is zero for the magnitude-less-than-divisor case
   and all ones for division by zero.
3. DIV versus REM selection in `rv64im_core_alu`: mask and OR `div_res` or the
   separately computed `rem_res`.
4. W-form extension: select either the 64-bit result or sign-extension of bit
   31 for DIVW/DIVUW/REMW/REMUW.
5. General result selection: mask and OR the ALU, branch/jump, MULDIV, and CSR
   result classes.
6. ID forwarding selection, audited separately.

The remainder path shifts `rem_reg` right by `~rvld_cnt_r`, then conditionally
computes `~rem_res_sel + 1` for a negative dividend. It is not the launch path
identified by the exact P1 trigger, but a future quotient cleanup must not
alter REM/REMU behavior.

## Expression structure

The quotient correction and fast-div behavior are two nested data selections.
The ALU then uses one-hot-style masked-OR expressions for DIV/REM selection
and for the general write-data result. W-form sign extension is a ternary.
There is no source-level duplicate quotient negation: the quotient and
remainder corrections are separate because their architectural signs differ.

Replacing `~res_reg + 1` with unary minus, or rewriting the masked-ORs as a
`case`, is algebraically equivalent but does not by itself establish a shorter
mapped topology. The exact P1 run must be repeated before crediting timing.

## Cleanup opportunities

### DRC1: completion-time signed quotient storage

- `CANDIDATE_ID=DRC1`
- `DESCRIPTION=On the final non-fast iterative update, fold quotient sign correction into the existing res_reg update so the acknowledged quotient is already architectural-sign-correct; remove the normal post-res_reg 64-bit correction from div_res.`
- `RTL_FILES_AFFECTED=rtl/vsrc/exu/rv64im_core_div.sv`
- `LOGIC_CONE_AFFECTED=res_reg final next-state and res_reg-to-div_res output cone`
- `FUNCTIONALLY_EQUIVALENT_EXPECTED=YES`
- `CYCLE_BEHAVIOR_CHANGED=NO`
- `NEW_REGISTER_REQUIRED=NO`
- `ESTIMATED_SCOPE=SMALL`
- `TIMING_RATIONALE=Moves the long two's-complement carry operation off the measured res_reg-to-ID forwarding launch cone; downstream selects remain, while correction terminates at the existing divider state boundary.`
- `CORRECTNESS_RISK=MODERATE`

This is the preferred future experiment, not an implemented or proven
transformation. Equivalence depends on identifying the actual final quotient
bit update correctly and preserving the acknowledged value when `div_ready`
is held by a downstream stall. Fast-div, division-by-zero, DIVU, all W forms,
signed overflow, flush/reset, and back-to-back requests are explicit tests.
The correction may become a new divider-internal setup path; only fresh STA
can show a net benefit.

### DRC2: explicit prefix-form two's-complement correction

- `CANDIDATE_ID=DRC2`
- `DESCRIPTION=Express signed quotient correction as an explicitly structured complement/increment prefix network while retaining the current register and output cycle.`
- `RTL_FILES_AFFECTED=rtl/vsrc/exu/rv64im_core_div.sv`
- `LOGIC_CONE_AFFECTED=div_res_sel signed quotient correction`
- `FUNCTIONALLY_EQUIVALENT_EXPECTED=YES`
- `CYCLE_BEHAVIOR_CHANGED=NO`
- `NEW_REGISTER_REQUIRED=NO`
- `ESTIMATED_SCOPE=MEDIUM`
- `TIMING_RATIONALE=A balanced prefix implementation could shorten carry depth relative to a ripple-like mapped negate, but tool recognition and area cost are uncertain.`
- `CORRECTNESS_RISK=MODERATE`

DRC2 is not preferred because it is more prescriptive and technology-sensitive
than DRC1 and may duplicate transformations already available to synthesis.

## Root-cause classification

- `DIV_ID_ROOT_CAUSE_PRIMARY=DIVIDER_FINAL_CORRECTION`
- `DIV_ID_ROOT_CAUSE_SECONDARY=COMBINATION_OF_GENERAL_EX_RESULT_MUX_AND_FORWARDING_PRIORITY_MUX`

The primary classification follows from the exact launch bit and the 64-bit
conditional two's-complement expression. The secondary classification reflects
the two broad selection structures that every acknowledged DIV result still
crosses before capture. No exact P1 evidence isolates high fanout or forwarding
control generation as the primary cause.
