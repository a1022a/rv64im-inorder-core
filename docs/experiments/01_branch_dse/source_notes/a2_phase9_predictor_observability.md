# A2 Phase 9 Predictor Observability

This phase adds simulation-only observability for P0 predictor replay. It does
not change predictor RTL, pipeline behavior, ROI definitions, Phase 6 exclusive
attribution, or Phase 7 episode semantics.

## RTL re-audit

The active `PRED_1` configuration defines `SAT_CNT` and `RAS` in
`rtl/vsrc/rv64im_core_defines.sv`. `rv64im_core_ifu.sv` instantiates the
tagless 1024-entry two-bit saturating-counter predictor using PC bits `[11:2]`;
`rv64im_core_ras` has 32 entries. At ALU resolution,
`cond_err = bx_if_cond & (jump_res ^ if_bx_predict_pt)` and
`jalr_err = ({bx_tgt[63:1], 1'b0} != idu_pc)`. With the active RAS,
`o_alu_flush = cond_err | (jalr & jalr_err)`. Thus JAL alone does not cause an
ALU recovery flush.

## Episode and trace definitions

- `conditional_direction_recovery_episode_count` is a sampled low-to-high
  transition of `perf_flush_branch && cond_err` while the ROI is active.
- `jalr_target_recovery_episode_count` is a sampled low-to-high transition of
  `perf_flush_branch && jalr && jalr_err` while the ROI is active.
- `other_recovery_episode_count` is a sampled low-to-high transition of
  `perf_flush_branch && !(conditional_direction_recovery ||
  jalr_target_recovery)` while the ROI is active.
- `conditional_branch_observations` records each non-stalled ALU-stage
  conditional resolution while the ROI is active: ALU PC, `jump_res` actual
  direction, and the IDU-to-EXU carried `if_bx_predict_pt` direction.

The three subtype levels are complete and mutually exclusive for each sampled
`perf_flush_branch` level under this configuration. Their independently
edge-qualified episode counts are deliberately not asserted to sum to the
existing `branch_recovery_episode_count`: adjacent episodes of different
subtypes can occur without an intervening sampled low `perf_flush_branch`.
The existing Phase 7 counter remains the union signal's low-to-high convention.
The trace is resolved predictor history, not architectural retirement; it does
not use `wb_sign` and contains no wrong-path observation claim.

## JSON change

The opt-in raw schema changes from `a2-raw-v2` to `a2-raw-v3` and adds the
three subtype episode counts plus `conditional_branch_observations` entries
with `cycle`, `pc`, `actual_taken`, and `predicted_taken`. The exact replay
extension advances the schema to `a2-raw-v4` and adds
`predictor_timeline_observations`.
