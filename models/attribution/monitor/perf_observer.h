#ifndef RV64IM_CORE_PERF_OBSERVER_H
#define RV64IM_CORE_PERF_OBSERVER_H

#include <stdint.h>

struct PerfObservation {
  uint64_t cycle;
  uint64_t pc;
  uint32_t inst;
  bool intr;
  bool device;
};

struct ConditionalBranchObservation {
  uint64_t cycle;
  uint64_t pc;
  bool actual_taken;
  bool predicted_taken;
};

struct PredictorTimelineObservation {
  uint64_t cycle;
  uint64_t event_id;
  const char *kind;
  uint64_t pc;
  uint16_t index;
  bool valid;
  uint8_t counter;
  bool fallback_sign;
  bool predicted_taken;
  bool actual_taken;
};

struct PredictorWarmupUpdateObservation {
  uint64_t sequence;
  uint64_t cycle;
  uint64_t pc;
  bool actual_taken;
};

void perf_observer_init();
void perf_observer_cycle();
void perf_observer_update_roi(bool wb_sign, uint64_t wb_pc);
void perf_observer_sample(bool wb_sign, uint64_t wb_pc, uint32_t wb_inst,
                          bool wb_intr, bool wb_device);
void perf_observer_sample_raw(bool branch_resolved, bool branch_direction_error,
                              bool jalr_target_error, bool icache_miss,
                              bool dcache_miss, bool icache_wait,
                              bool dcache_memory_wait, bool load_use_stall,
                              bool divider_wait, bool flush_event,
                              bool flush_branch, bool flush_interrupt,
                              bool dependency_stall,
                              bool conditional_direction_recovery,
                              bool jalr_target_recovery,
                              bool other_recovery,
                              bool conditional_branch_resolved,
                              uint64_t conditional_branch_pc,
                              bool conditional_branch_actual_taken,
                              bool conditional_branch_predicted_taken,
                              bool predictor_lookup_event,
                              uint64_t predictor_lookup_pc,
                              uint64_t predictor_lookup_id,
                              bool predictor_lookup_valid,
                              uint8_t predictor_lookup_counter,
                              bool predictor_fetch_event,
                              uint64_t predictor_fetch_pc,
                              bool predictor_fetch_conditional,
                              bool predictor_fetch_fallback_sign,
                              bool predictor_fetch_predicted_taken,
                              uint64_t predictor_fetch_id,
                              bool predictor_update_event,
                              uint64_t predictor_update_pc,
                              bool predictor_update_actual_taken,
                              uint64_t predictor_update_id);
int perf_observer_finalize(uint64_t brn_num, uint64_t bflush_num,
                           int exit_status);

#endif
