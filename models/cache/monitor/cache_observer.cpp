#include "cache_observer.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace {
const char* output_path;
const char* trace_path;
FILE* trace_file;
bool trace_open_failed;
uint64_t trace_sequence;
uint64_t trace_cycle;
bool roi_requested;
bool roi_active;
bool roi_started;
bool roi_ended;
uint64_t roi_start_pc;
uint64_t roi_end_pc;

struct Counts {
  uint64_t cycles;
  uint64_t writeback_observations;
  uint64_t icache_accesses;
  uint64_t icache_hits;
  uint64_t icache_misses;
  uint64_t icache_refill_starts;
  uint64_t icache_refill_completions;
  uint64_t icache_miss_stall_cycles;
  uint64_t icache_total_stall_cycles;
  uint64_t dcache_accesses;
  uint64_t dcache_load_accesses;
  uint64_t dcache_store_accesses;
  uint64_t dcache_hits;
  uint64_t dcache_misses;
  uint64_t dcache_load_hits;
  uint64_t dcache_load_misses;
  uint64_t dcache_store_hits;
  uint64_t dcache_store_misses;
  uint64_t dcache_refill_starts;
  uint64_t dcache_refill_completions;
  uint64_t dcache_dirty_evictions;
  uint64_t dcache_writeback_starts;
  uint64_t dcache_writeback_completions;
  uint64_t dcache_miss_stall_cycles;
  uint64_t dcache_writeback_stall_cycles;
  uint64_t dcache_total_stall_cycles;
  uint64_t exclusive_dcache_cycles;
  uint64_t exclusive_divider_cycles;
  uint64_t exclusive_branch_cycles;
  uint64_t exclusive_dependency_cycles;
  uint64_t exclusive_icache_cycles;
  uint64_t exclusive_other_cycles;
};

Counts counts;

bool parse_u64_env(const char* name, uint64_t* value) {
  const char* text = std::getenv(name);
  if (!text || !*text) return false;
  char* end = nullptr;
  *value = std::strtoull(text, &end, 0);
  return end && *end == '\0';
}

bool collecting() { return output_path && (!roi_requested || roi_active); }

void reset_counts() { std::memset(&counts, 0, sizeof(counts)); }

void emit_u64(FILE* file, const char* name, uint64_t value, bool comma = true) {
  std::fprintf(file, "  \"%s\": %llu%s\n", name,
               static_cast<unsigned long long>(value), comma ? "," : "");
}
}  // namespace

void cache_observer_init() {
  output_path = std::getenv("CACHE_PROFILE_OUT");
  trace_path = std::getenv("DCACHE_TRACE_OUT");
  trace_file = nullptr;
  trace_open_failed = false;
  trace_sequence = 0;
  trace_cycle = 0;
  const bool has_start = parse_u64_env("PERF_ROI_START_PC", &roi_start_pc);
  const bool has_end = parse_u64_env("PERF_ROI_END_PC", &roi_end_pc);
  roi_requested = has_start || has_end;
  if (output_path && (has_start != has_end || (roi_requested && roi_start_pc == roi_end_pc))) {
    std::fprintf(stderr, "cache observer: invalid PERF_ROI_START_PC/PERF_ROI_END_PC\n");
    output_path = nullptr;
  }
  roi_active = !roi_requested;
  roi_started = !roi_requested;
  roi_ended = false;
  reset_counts();
  if (trace_path) {
    trace_file = std::fopen(trace_path, "w");
    if (!trace_file) {
      trace_open_failed = true;
      std::fprintf(stderr, "cache observer: cannot open DCACHE_TRACE_OUT=%s\n", trace_path);
    } else {
      std::fprintf(trace_file,
                   "sequence_number,simulation_cycle,phase,address,operation,wmask,rtl_hit,rtl_miss,rtl_dirty_eviction\n");
    }
  }
}

void cache_observer_update_roi(bool wb_sign, uint64_t wb_pc) {
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

void cache_observer_cycle() {
  if (trace_file && !roi_ended) ++trace_cycle;
  if (collecting()) ++counts.cycles;
}

void cache_observer_sample(const CacheObserverSample& sample) {
  if (trace_file && !roi_ended && sample.dcache_access) {
    std::fprintf(trace_file, "%llu,%llu,%s,0x%08x,%s,0x%02x,%u,%u,%u\n",
                 static_cast<unsigned long long>(trace_sequence++),
                 static_cast<unsigned long long>(trace_cycle),
                 roi_active ? "ROI" : "PRE_ROI", sample.dcache_address,
                 sample.dcache_store_access ? "STORE" : "LOAD", sample.dcache_wmask,
                 sample.dcache_hit, sample.dcache_miss, sample.dcache_dirty_eviction);
  }
  if (!collecting()) return;
  counts.icache_accesses += sample.icache_access;
  counts.icache_hits += sample.icache_hit;
  counts.icache_misses += sample.icache_miss;
  counts.icache_refill_starts += sample.icache_refill_start;
  counts.icache_refill_completions += sample.icache_refill_complete;
  counts.icache_miss_stall_cycles += sample.icache_miss_stall;
  counts.icache_total_stall_cycles += sample.icache_total_stall;
  counts.dcache_accesses += sample.dcache_access;
  counts.dcache_load_accesses += sample.dcache_load_access;
  counts.dcache_store_accesses += sample.dcache_store_access;
  counts.dcache_hits += sample.dcache_hit;
  counts.dcache_misses += sample.dcache_miss;
  counts.dcache_load_hits += sample.dcache_hit && sample.dcache_load_access;
  counts.dcache_load_misses += sample.dcache_miss && sample.dcache_load_access;
  counts.dcache_store_hits += sample.dcache_hit && sample.dcache_store_access;
  counts.dcache_store_misses += sample.dcache_miss && sample.dcache_store_access;
  counts.dcache_refill_starts += sample.dcache_refill_start;
  counts.dcache_refill_completions += sample.dcache_refill_complete;
  counts.dcache_dirty_evictions += sample.dcache_dirty_eviction;
  counts.dcache_writeback_starts += sample.dcache_writeback_start;
  counts.dcache_writeback_completions += sample.dcache_writeback_complete;
  counts.dcache_miss_stall_cycles += sample.dcache_miss_stall;
  counts.dcache_writeback_stall_cycles += sample.dcache_writeback_stall;
  counts.dcache_total_stall_cycles += sample.dcache_total_stall;
  if (sample.dcache_total_stall) {
    ++counts.exclusive_dcache_cycles;
  } else if (sample.divider) {
    ++counts.exclusive_divider_cycles;
  } else if (sample.branch_recovery) {
    ++counts.exclusive_branch_cycles;
  } else if (sample.dependency) {
    ++counts.exclusive_dependency_cycles;
  } else if (sample.icache_total_stall) {
    ++counts.exclusive_icache_cycles;
  } else {
    ++counts.exclusive_other_cycles;
  }
}

void cache_observer_sample_writeback(bool wb_sign, uint64_t wb_pc) {
  if (!collecting() || !wb_sign) return;
  if (roi_requested && (wb_pc == roi_start_pc || wb_pc == roi_end_pc)) return;
  ++counts.writeback_observations;
}

int cache_observer_finalize(int exit_status) {
  if (trace_file) {
    std::fclose(trace_file);
    trace_file = nullptr;
  }
  if (!output_path) return trace_open_failed ? 1 : 0;
  const uint64_t exclusive_sum = counts.exclusive_dcache_cycles +
      counts.exclusive_divider_cycles + counts.exclusive_branch_cycles +
      counts.exclusive_dependency_cycles + counts.exclusive_icache_cycles +
      counts.exclusive_other_cycles;
  const bool roi_valid = !roi_requested || (roi_started && roi_ended);
  const bool invariant_ok = counts.icache_accesses == counts.icache_hits + counts.icache_misses &&
      counts.dcache_accesses == counts.dcache_load_accesses + counts.dcache_store_accesses &&
      counts.dcache_accesses == counts.dcache_hits + counts.dcache_misses &&
      counts.dcache_load_accesses == counts.dcache_load_hits + counts.dcache_load_misses &&
      counts.dcache_store_accesses == counts.dcache_store_hits + counts.dcache_store_misses &&
      exclusive_sum == counts.cycles;
  FILE* file = std::fopen(output_path, "w");
  if (!file) return 1;
  std::fprintf(file, "{\n  \"schema_version\": \"a2-cache-c0-v1\",\n");
  std::fprintf(file, "  \"roi_valid\": %s,\n", roi_valid ? "true" : "false");
  std::fprintf(file, "  \"retirement_status\": \"NOT_QUALIFIED_PARTIAL_WB_EVENT\",\n");
  emit_u64(file, "roi_cycles", counts.cycles);
  emit_u64(file, "writeback_observations", counts.writeback_observations);
  emit_u64(file, "icache_accesses", counts.icache_accesses);
  emit_u64(file, "icache_hits", counts.icache_hits);
  emit_u64(file, "icache_misses", counts.icache_misses);
  emit_u64(file, "icache_miss_allocated_in_roi", counts.icache_misses);
  emit_u64(file, "icache_refill_started_in_roi", counts.icache_refill_starts);
  emit_u64(file, "icache_refill_completed_in_roi", counts.icache_refill_completions);
  emit_u64(file, "icache_miss_stall_cycles", counts.icache_miss_stall_cycles);
  emit_u64(file, "icache_total_stall_cycles", counts.icache_total_stall_cycles);
  emit_u64(file, "dcache_accesses", counts.dcache_accesses);
  emit_u64(file, "dcache_load_accesses", counts.dcache_load_accesses);
  emit_u64(file, "dcache_store_accesses", counts.dcache_store_accesses);
  emit_u64(file, "dcache_hits", counts.dcache_hits);
  emit_u64(file, "dcache_misses", counts.dcache_misses);
  emit_u64(file, "dcache_load_hits", counts.dcache_load_hits);
  emit_u64(file, "dcache_load_misses", counts.dcache_load_misses);
  emit_u64(file, "dcache_store_hits", counts.dcache_store_hits);
  emit_u64(file, "dcache_store_misses", counts.dcache_store_misses);
  emit_u64(file, "dcache_miss_allocated_in_roi", counts.dcache_misses);
  emit_u64(file, "dcache_refill_started_in_roi", counts.dcache_refill_starts);
  emit_u64(file, "dcache_refill_completed_in_roi", counts.dcache_refill_completions);
  emit_u64(file, "dcache_dirty_evictions", counts.dcache_dirty_evictions);
  emit_u64(file, "dcache_writeback_started_in_roi", counts.dcache_writeback_starts);
  emit_u64(file, "dcache_writeback_completed_in_roi", counts.dcache_writeback_completions);
  emit_u64(file, "dcache_miss_stall_cycles", counts.dcache_miss_stall_cycles);
  emit_u64(file, "dcache_writeback_stall_cycles", counts.dcache_writeback_stall_cycles);
  emit_u64(file, "dcache_total_stall_cycles", counts.dcache_total_stall_cycles);
  emit_u64(file, "exclusive_dcache_cycles", counts.exclusive_dcache_cycles);
  emit_u64(file, "exclusive_divider_cycles", counts.exclusive_divider_cycles);
  emit_u64(file, "exclusive_branch_cycles", counts.exclusive_branch_cycles);
  emit_u64(file, "exclusive_dependency_cycles", counts.exclusive_dependency_cycles);
  emit_u64(file, "exclusive_icache_cycles", counts.exclusive_icache_cycles);
  emit_u64(file, "exclusive_other_cycles", counts.exclusive_other_cycles);
  emit_u64(file, "exclusive_cycle_sum", exclusive_sum);
  std::fprintf(file, "  \"counter_invariants_pass\": %s,\n", invariant_ok ? "true" : "false");
  std::fprintf(file, "  \"exit_status\": %d\n}\n", exit_status);
  std::fclose(file);
  return roi_valid && invariant_ok && !trace_open_failed ? 0 : 1;
}
