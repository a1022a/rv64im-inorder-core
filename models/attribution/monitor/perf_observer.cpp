#include "perf_observer.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vector>

namespace {
const char *output_path = NULL;
const char *workload = NULL;
const char *git_commit = NULL;
const char *a2_base_commit = "df956d23cc420b761104f359792cfbd5bb5e4747";
const char *schema_version = "a2-raw-v4";
bool roi_requested = false;
bool roi_active = false;
bool roi_started = false;
bool roi_ended = false;
uint64_t roi_start_pc = 0;
uint64_t roi_end_pc = 0;
uint64_t cycle_count = 0;
uint64_t wb_intr_count = 0;
uint64_t wb_device_count = 0;
std::vector<PerfObservation> observations;
std::vector<ConditionalBranchObservation> conditional_branch_observations;
std::vector<PredictorTimelineObservation> predictor_timeline_observations;
std::vector<PredictorWarmupUpdateObservation> predictor_warmup_updates;
uint64_t predictor_warmup_update_sequence = 0;
uint64_t branch_resolved_count = 0, branch_direction_error_count = 0;
uint64_t jalr_target_error_count = 0, icache_miss_count = 0, dcache_miss_count = 0;
uint64_t icache_wait_cycles = 0, dcache_memory_wait_cycles = 0;
uint64_t load_use_stall_cycles = 0, divider_wait_cycles = 0;
uint64_t flush_count = 0, flush_branch_count = 0, flush_interrupt_count = 0;
uint64_t dependency_stall_cycles = 0;
uint64_t exclusive_dcache_memory_wait_cycles = 0;
uint64_t exclusive_divider_block_cycles = 0;
uint64_t exclusive_branch_recovery_cycles = 0;
uint64_t exclusive_dependency_load_use_cycles = 0;
uint64_t exclusive_icache_wait_cycles = 0;
uint64_t exclusive_other_unclassified_cycles = 0;
uint64_t dependency_load_use_episode_count = 0;
uint64_t branch_recovery_episode_count = 0;
uint64_t conditional_direction_recovery_episode_count = 0;
uint64_t jalr_target_recovery_episode_count = 0;
uint64_t other_recovery_episode_count = 0;
bool previous_load_use_stall = false;
bool previous_flush_branch = false;
bool previous_conditional_direction_recovery = false;
bool previous_jalr_target_recovery = false;
bool previous_other_recovery = false;

const char *env_or(const char *name, const char *fallback) {
  const char *value = getenv(name);
  return value && value[0] ? value : fallback;
}

bool parse_u64_env(const char *name, uint64_t *value) {
  const char *text = getenv(name);
  if (!text || !text[0]) return false;
  char *end = NULL;
  unsigned long long parsed = strtoull(text, &end, 0);
  if (!end || end == text || *end != '\0') return false;
  *value = parsed;
  return true;
}

bool collecting() {
  return output_path && (!roi_requested || roi_active);
}

void reset_counts() {
  cycle_count = 0;
  wb_intr_count = 0;
  wb_device_count = 0;
  observations.clear();
  conditional_branch_observations.clear();
  predictor_timeline_observations.clear();
  branch_resolved_count = branch_direction_error_count = jalr_target_error_count = 0;
  icache_miss_count = dcache_miss_count = 0;
  icache_wait_cycles = dcache_memory_wait_cycles = 0;
  load_use_stall_cycles = divider_wait_cycles = 0;
  flush_count = flush_branch_count = flush_interrupt_count = dependency_stall_cycles = 0;
  exclusive_dcache_memory_wait_cycles = exclusive_divider_block_cycles = 0;
  exclusive_branch_recovery_cycles = exclusive_dependency_load_use_cycles = 0;
  exclusive_icache_wait_cycles = exclusive_other_unclassified_cycles = 0;
  dependency_load_use_episode_count = branch_recovery_episode_count = 0;
  conditional_direction_recovery_episode_count = 0;
  jalr_target_recovery_episode_count = 0;
  other_recovery_episode_count = 0;
  previous_load_use_stall = previous_flush_branch = false;
  previous_conditional_direction_recovery = false;
  previous_jalr_target_recovery = false;
  previous_other_recovery = false;
}

void write_json_string(FILE *file, const char *value) {
  fputc('"', file);
  for (const char *cursor = value; *cursor; ++cursor) {
    if (*cursor == '"' || *cursor == '\\') fputc('\\', file);
    fputc(*cursor, file);
  }
  fputc('"', file);
}
}

void perf_observer_init() {
  output_path = getenv("PERF_RAW_OUT");
  if (!output_path || !output_path[0]) return;
  workload = env_or("PERF_WORKLOAD", "unspecified");
  git_commit = env_or("PERF_GIT_COMMIT", "unspecified");
  bool has_start = parse_u64_env("PERF_ROI_START_PC", &roi_start_pc);
  bool has_end = parse_u64_env("PERF_ROI_END_PC", &roi_end_pc);
  roi_requested = has_start || has_end;
  if (has_start != has_end || (roi_requested && roi_start_pc == roi_end_pc)) {
    fprintf(stderr, "performance observer: PERF_ROI_START_PC and PERF_ROI_END_PC must be distinct valid addresses\n");
    output_path = NULL;
    return;
  }
  roi_active = !roi_requested;
  roi_started = !roi_requested;
  roi_ended = false;
  predictor_warmup_updates.clear();
  predictor_warmup_update_sequence = 0;
  reset_counts();
}

void perf_observer_update_roi(bool wb_sign, uint64_t wb_pc) {
  if (!output_path || !roi_requested || !wb_sign) return;
  if (!roi_started && wb_pc == roi_start_pc) {
    reset_counts();
    roi_started = true;
    roi_active = true;
  } else if (roi_active && wb_pc == roi_end_pc) {
    roi_active = false;
    roi_ended = true;
  }
}

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
                              uint64_t predictor_update_id) {
  if (output_path && roi_requested && !roi_started && predictor_update_event) {
    predictor_warmup_updates.push_back(
        {predictor_warmup_update_sequence++, cycle_count, predictor_update_pc,
         predictor_update_actual_taken});
  }
  if (!collecting()) return;
  branch_resolved_count += branch_resolved;
  branch_direction_error_count += branch_direction_error;
  jalr_target_error_count += jalr_target_error;
  icache_miss_count += icache_miss;
  dcache_miss_count += dcache_miss;
  icache_wait_cycles += icache_wait;
  dcache_memory_wait_cycles += dcache_memory_wait;
  load_use_stall_cycles += load_use_stall;
  divider_wait_cycles += divider_wait;
  flush_count += flush_event;
  flush_branch_count += flush_branch;
  flush_interrupt_count += flush_interrupt;
  dependency_stall_cycles += dependency_stall;
  if (load_use_stall && !previous_load_use_stall) ++dependency_load_use_episode_count;
  if (flush_branch && !previous_flush_branch) ++branch_recovery_episode_count;
  if (conditional_direction_recovery && !previous_conditional_direction_recovery) {
    ++conditional_direction_recovery_episode_count;
  }
  if (jalr_target_recovery && !previous_jalr_target_recovery) {
    ++jalr_target_recovery_episode_count;
  }
  if (other_recovery && !previous_other_recovery) ++other_recovery_episode_count;
  if (conditional_branch_resolved) {
    conditional_branch_observations.push_back(
        {cycle_count, conditional_branch_pc, conditional_branch_actual_taken,
         conditional_branch_predicted_taken});
  }
  if (predictor_lookup_event) {
    predictor_timeline_observations.push_back(
        {cycle_count, predictor_lookup_id, "lookup", predictor_lookup_pc,
         static_cast<uint16_t>((predictor_lookup_pc >> 2) & 0x3ff),
         predictor_lookup_valid, predictor_lookup_counter, false, false, false});
  }
  if (predictor_fetch_event && predictor_fetch_conditional) {
    predictor_timeline_observations.push_back(
        {cycle_count, predictor_fetch_id, "prediction", predictor_fetch_pc,
         static_cast<uint16_t>((predictor_fetch_pc >> 2) & 0x3ff), false, 0,
         predictor_fetch_fallback_sign, predictor_fetch_predicted_taken, false});
  }
  if (predictor_update_event) {
    predictor_timeline_observations.push_back(
        {cycle_count, predictor_update_id, "update", predictor_update_pc,
         static_cast<uint16_t>((predictor_update_pc >> 2) & 0x3ff), false, 0,
         false, false, predictor_update_actual_taken});
  }
  previous_load_use_stall = load_use_stall;
  previous_flush_branch = flush_branch;
  previous_conditional_direction_recovery = conditional_direction_recovery;
  previous_jalr_target_recovery = jalr_target_recovery;
  previous_other_recovery = other_recovery;
  if (dcache_memory_wait) {
    ++exclusive_dcache_memory_wait_cycles;
  } else if (divider_wait) {
    ++exclusive_divider_block_cycles;
  } else if (flush_branch) {
    ++exclusive_branch_recovery_cycles;
  } else if (load_use_stall) {
    ++exclusive_dependency_load_use_cycles;
  } else if (icache_wait) {
    ++exclusive_icache_wait_cycles;
  } else {
    ++exclusive_other_unclassified_cycles;
  }
}

void perf_observer_cycle() {
  if (collecting()) ++cycle_count;
}

void perf_observer_sample(bool wb_sign, uint64_t wb_pc, uint32_t wb_inst,
                          bool wb_intr, bool wb_device) {
  if (!collecting() || !wb_sign) return;
  if (roi_requested && (wb_pc == roi_start_pc || wb_pc == roi_end_pc)) return;
  observations.push_back({cycle_count, wb_pc, wb_inst, wb_intr, wb_device});
  wb_intr_count += wb_intr;
  wb_device_count += wb_device;
}

int perf_observer_finalize(uint64_t brn_num, uint64_t bflush_num,
                           int exit_status) {
  if (!output_path) return 0;
  const uint64_t exclusive_cycle_sum = exclusive_dcache_memory_wait_cycles +
      exclusive_divider_block_cycles + exclusive_branch_recovery_cycles +
      exclusive_dependency_load_use_cycles + exclusive_icache_wait_cycles +
      exclusive_other_unclassified_cycles;
  const bool exclusive_cycle_sum_matches_roi = exclusive_cycle_sum == cycle_count;
  if (roi_requested && roi_started && roi_ended && !exclusive_cycle_sum_matches_roi) {
    fprintf(stderr, "performance observer: exclusive cycle sum mismatch: %llu != %llu\n",
            (unsigned long long)exclusive_cycle_sum,
            (unsigned long long)cycle_count);
    exit_status = 1;
  }
  FILE *file = fopen(output_path, "w");
  if (!file) {
    fprintf(stderr, "performance observer: cannot open %s\n", output_path);
    return 1;
  }
  fprintf(file, "{\n  \"schema_version\": ");
  write_json_string(file, schema_version);
  fprintf(file, ",\n  \"git_commit\": ");
  write_json_string(file, git_commit);
  fprintf(file, ",\n  \"a2_base_commit\": ");
  write_json_string(file, a2_base_commit);
  fprintf(file, ",\n  \"workload\": ");
  write_json_string(file, workload);
  fprintf(file, ",\n  \"measurement_scope\": \"");
  fputs(roi_requested ? "pc_marker_roi" : "full_run", file);
  fprintf(file, "\",\n  \"roi_valid\": %s,\n", roi_requested && roi_started && roi_ended ? "true" : "false");
  if (roi_requested) {
    fprintf(file, "  \"roi_start_pc\": \"0x%016llx\",\n  \"roi_end_pc\": \"0x%016llx\",\n",
            (unsigned long long)roi_start_pc, (unsigned long long)roi_end_pc);
  }
  fprintf(file, "  \"simulator_cycle_count\": %llu,\n",
          (unsigned long long)cycle_count);
  fprintf(file, "  \"wb_observation_count\": %llu,\n",
          (unsigned long long)observations.size());
  fprintf(file, "  \"wb_intr_count\": %llu,\n",
          (unsigned long long)wb_intr_count);
  fprintf(file, "  \"wb_device_count\": %llu,\n",
          (unsigned long long)wb_device_count);
  fprintf(file, "  \"branch_resolved_observation_count\": %llu,\n",
          (unsigned long long)branch_resolved_count);
  fprintf(file, "  \"branch_direction_error_count\": %llu,\n",
          (unsigned long long)branch_direction_error_count);
  fprintf(file, "  \"jalr_target_error_count\": %llu,\n",
          (unsigned long long)jalr_target_error_count);
  fprintf(file, "  \"icache_miss_observation_count\": %llu,\n",
          (unsigned long long)icache_miss_count);
  fprintf(file, "  \"dcache_miss_observation_count\": %llu,\n",
          (unsigned long long)dcache_miss_count);
  fprintf(file, "  \"icache_wait_cycles\": %llu,\n",
          (unsigned long long)icache_wait_cycles);
  fprintf(file, "  \"dcache_memory_wait_cycles\": %llu,\n",
          (unsigned long long)dcache_memory_wait_cycles);
  fprintf(file, "  \"load_use_stall_cycles\": %llu,\n",
          (unsigned long long)load_use_stall_cycles);
  fprintf(file, "  \"divider_wait_cycles\": %llu,\n",
          (unsigned long long)divider_wait_cycles);
  fprintf(file, "  \"flush_observation_count\": %llu,\n",
          (unsigned long long)flush_count);
  fprintf(file, "  \"flush_branch_count\": %llu,\n  \"flush_interrupt_count\": %llu,\n  \"dependency_stall_cycles\": %llu,\n",
          (unsigned long long)flush_branch_count,
          (unsigned long long)flush_interrupt_count,
          (unsigned long long)dependency_stall_cycles);
  fprintf(file, "  \"exclusive_dcache_memory_wait_cycles\": %llu,\n",
          (unsigned long long)exclusive_dcache_memory_wait_cycles);
  fprintf(file, "  \"exclusive_divider_block_cycles\": %llu,\n",
          (unsigned long long)exclusive_divider_block_cycles);
  fprintf(file, "  \"exclusive_branch_recovery_cycles\": %llu,\n",
          (unsigned long long)exclusive_branch_recovery_cycles);
  fprintf(file, "  \"exclusive_dependency_load_use_cycles\": %llu,\n",
          (unsigned long long)exclusive_dependency_load_use_cycles);
  fprintf(file, "  \"exclusive_icache_wait_cycles\": %llu,\n",
          (unsigned long long)exclusive_icache_wait_cycles);
  fprintf(file, "  \"exclusive_other_unclassified_cycles\": %llu,\n",
          (unsigned long long)exclusive_other_unclassified_cycles);
  fprintf(file, "  \"exclusive_cycle_sum\": %llu,\n  \"exclusive_cycle_sum_matches_roi\": %s,\n",
          (unsigned long long)exclusive_cycle_sum,
          exclusive_cycle_sum_matches_roi ? "true" : "false");
  fprintf(file, "  \"dependency_load_use_episode_count\": %llu,\n",
          (unsigned long long)dependency_load_use_episode_count);
  fprintf(file, "  \"branch_recovery_episode_count\": %llu,\n",
          (unsigned long long)branch_recovery_episode_count);
  fprintf(file, "  \"conditional_direction_recovery_episode_count\": %llu,\n",
          (unsigned long long)conditional_direction_recovery_episode_count);
  fprintf(file, "  \"jalr_target_recovery_episode_count\": %llu,\n",
          (unsigned long long)jalr_target_recovery_episode_count);
  fprintf(file, "  \"other_recovery_episode_count\": %llu,\n",
          (unsigned long long)other_recovery_episode_count);
  fprintf(file, "  \"predictor_warmup_updates\": [\n");
  for (size_t index = 0; index < predictor_warmup_updates.size(); ++index) {
    const PredictorWarmupUpdateObservation &observation = predictor_warmup_updates[index];
    fprintf(file, "    {\"sequence\": %llu, \"cycle\": %llu, \"pc\": \"0x%016llx\", \"actual_taken\": %s}%s\n",
            (unsigned long long)observation.sequence,
            (unsigned long long)observation.cycle,
            (unsigned long long)observation.pc,
            observation.actual_taken ? "true" : "false",
            index + 1 == predictor_warmup_updates.size() ? "" : ",");
  }
  fprintf(file, "  ],\n");
  fprintf(file, "  \"predictor_timeline_observations\": [\n");
  for (size_t index = 0; index < predictor_timeline_observations.size(); ++index) {
    const PredictorTimelineObservation &observation = predictor_timeline_observations[index];
    fprintf(file, "    {\"cycle\": %llu, \"kind\": \"%s\", \"pc\": \"0x%016llx\", \"event_id\": %llu, \"index\": %u, \"valid\": %s, \"counter\": %u, \"fallback_sign\": %s, \"predicted_taken\": %s, \"actual_taken\": %s}%s\n",
            (unsigned long long)observation.cycle, observation.kind,
            (unsigned long long)observation.pc,
            (unsigned long long)observation.event_id, observation.index,
            observation.valid ? "true" : "false", observation.counter,
            observation.fallback_sign ? "true" : "false",
            observation.predicted_taken ? "true" : "false",
            observation.actual_taken ? "true" : "false",
            index + 1 == predictor_timeline_observations.size() ? "" : ",");
  }
  fprintf(file, "  ],\n");
  fprintf(file, "  \"conditional_branch_observations\": [\n");
  for (size_t index = 0; index < conditional_branch_observations.size(); ++index) {
    const ConditionalBranchObservation &observation = conditional_branch_observations[index];
    fprintf(file, "    {\"cycle\": %llu, \"pc\": \"0x%016llx\", \"actual_taken\": %s, \"predicted_taken\": %s}%s\n",
            (unsigned long long)observation.cycle,
            (unsigned long long)observation.pc,
            observation.actual_taken ? "true" : "false",
            observation.predicted_taken ? "true" : "false",
            index + 1 == conditional_branch_observations.size() ? "" : ",");
  }
  fprintf(file, "  ],\n  \"brn_num\": %llu,\n  \"bflush_num\": %llu,\n",
          (unsigned long long)brn_num, (unsigned long long)bflush_num);
  fprintf(file, "  \"observations\": [\n");
  for (size_t index = 0; index < observations.size(); ++index) {
    const PerfObservation &observation = observations[index];
    fprintf(file, "    {\"cycle\": %llu, \"wb_pc\": \"0x%016llx\", \"wb_inst\": \"0x%08x\", \"wb_intr\": %s, \"wb_device\": %s}%s\n",
            (unsigned long long)observation.cycle,
            (unsigned long long)observation.pc, observation.inst,
            observation.intr ? "true" : "false",
            observation.device ? "true" : "false",
            index + 1 == observations.size() ? "" : ",");
  }
  fprintf(file, "  ],\n  \"exit_status\": %d\n}\n", exit_status);
  fclose(file);
  printf("PERF_RAW: wrote %s cycles=%llu wb_observations=%llu brn=%llu bflush=%llu\n",
         output_path, (unsigned long long)cycle_count,
         (unsigned long long)observations.size(),
         (unsigned long long)brn_num, (unsigned long long)bflush_num);
  return exclusive_cycle_sum_matches_roi ? 0 : 1;
}
