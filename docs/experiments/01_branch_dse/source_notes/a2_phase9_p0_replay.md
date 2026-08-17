# A2 Phase 9 P0 Conditional Predictor Replay

## P0 RTL semantics

`rv64im_core_satcnt` has 1,024 tagless two-bit counter locations, indexed by
`i_*_pc[11:2]` (the `BITS = 10` slice `i_*_pc[2 +: BITS]`). Its prediction
bit is `cnt_val[1]`: states `2'b10` and `2'b11` predict taken; `2'b00` and
`2'b01` predict not taken. For generated entries 0 through 1022, reset sets
the counter to `2'b10` and `cnt_vld` to zero. A resolved conditional branch
increments a non-saturated counter on taken, decrements a nonzero counter on
not taken, and sets `cnt_vld`, independent of EXU/IFU stall or flush inputs.
The source's generate bound is `i < DEPTH-1`; entry 1023 is consequently not
reset, valid-initialized, or updated by this module and must not be modeled as
a normal P0 entry without separate evidence.

Lookup is registered on an IFU `addr_shake` (`i_pred_en`), reading the indexed
counter and valid bit. IFU predicts a conditional from the counter only when
the registered valid bit is true; otherwise it uses the branch displacement
sign (`inst[31]`). The selected prediction is then carried through two
separately stallable/flushable registers: IFU-to-IDU and IDU-to-EXU. Update is
at the ALU resolution edge using `bx_if_cond` and `bx_if_pt`. Thus every
resolved conditional branch updates its normal table entry, but a later branch
can have looked up the same entry before that update becomes visible.

## Trace sufficiency and replay status

`conditional_branch_observations` provides resolution cycle, PC, actual
direction, and RTL prediction. In `a2-raw-v3` it omits fetch/lookup acceptance cycle,
instruction displacement sign, and the table state/lookup ordering among
in-flight aliases. It cannot prove that resolution-order replay reproduces
the RTL fetch-time prediction, especially for cold entries and same-index
branches in flight.

`models/replay_p0_conditional_predictor.py` therefore initializes modeled
entries exactly as RTL does and applies the RTL saturating updates in resolution
order. For a cold valid-bit-zero lookup, it uses recorded `predicted_taken`
only as a calibration oracle because the required displacement sign is absent.
It flags entry 1023 as unsupported. Its non-oracle comparison is a diagnostic,
not proof of an exact P0 replay. It reports per-event disagreements separately
from the sampled conditional recovery episode count; the latter can collapse
adjacent high levels and is not an architectural misprediction count.

## Exact timeline extension

The `a2-raw-v4` simulation-only `predictor_timeline_observations` adds ordered
same-sampled-cycle entries. The observer writes `lookup`, then `prediction`,
then `update`, matching the predictor's pre-edge lookup read followed by the
edge's nonblocking state updates. A `lookup` is IFU `addr_shake` and records
the accepted `pc_next`, PC-derived index, and the post-edge registered
`pred_vld`/`cnt_val`; those registers contain the entry valid/counter sampled
before that edge. An `update` is ALU `bx_if_cond`, recording ALU PC/index and
`jump_res`; it is deliberately not stall-gated because the RTL update block is
not stall-gated.

A `prediction` is an accepted IFU-to-IDU valid conditional instruction. It
records IFU PC, `inst[31]`, and the selected prediction supplied to the IDU.
The trace has one outstanding IFU request at a time (`rsp_rdy` gates the next
request), so lookup and delivered instruction can be paired in time and by PC
without functional pipeline metadata. ROI-scoped lookup snapshots establish
the RTL-visible starting state for entries first encountered within the frozen
ROI; selected prediction remains a comparison oracle only, not replay input.

Matched prediction/update IDs are resolved transactions. Prediction-only IDs
are speculative unresolved events: they are validated against RTL direction,
do not update state, and do not count direction errors. Update-only IDs are
ROI-boundary carry-ins; unknown pre-ROI state is recorded without invention and
the first later lookup snapshot establishes ROI-local state. This is exactly
calibrated for fully observed frozen-ROI P0 transactions, but not DSE-qualified:
candidate pre-ROI state and speculative fetch streams may change.

## Candidate warm-up stream

For a PC-marker ROI, `predictor_warmup_updates` records every post-reset
ALU `bx_if_cond` update before the ROI-start marker is processed. Each record
contains ordered `sequence`, simulator `cycle`, ALU PC, and `jump_res` actual
direction. The raw sample immediately before start-marker writeback belongs to
warm-up; the marker itself is excluded because it is only a wrapper writeback
boundary, not a predictor-update qualification. `reset_counts()` leaves the
warm-up stream intact, so frozen ROI counters and timeline semantics are
unchanged. The stream is training evidence, not architectural retirement.

The warm-up-aware replay initializes all implemented entries from the RTL reset
state (`counter = 2'b10`, `valid = false`), processes warm-up records strictly
by `sequence`, and ignores their non-informative `cycle` value. It never uses
RTL lookup state to repair software state: every ROI lookup is a comparison.
FIB's 33,813 warm-up updates and bubble-sort's empty warm-up stream both
reproduce zero lookup-state and prediction mismatches. Bubble's update-only
ROI event therefore applies to a known reset entry rather than unknown state.
This status is `PRE_ROI_WARMUP_CALIBRATED` for P0; no candidate sweep follows
from this calibration alone.
