#ifndef RV64IM_CORE_DEPENDENCY_OBSERVER_H
#define RV64IM_CORE_DEPENDENCY_OBSERVER_H

#include <cstdint>

struct DependencyObserverSample {
  bool dependency_stall;
  bool dcache_total_stall;
  bool divider_stall;
  bool branch_recovery;
  bool dcache_load_access;
  bool dcache_hit;
  bool dcache_miss;
  uint32_t dcache_address;
  uint64_t consumer_pc;
  uint32_t consumer_inst;
  uint64_t producer_pc;
  uint32_t producer_inst;
  uint8_t producer_rd;
  uint64_t producer_address;
};

void dependency_observer_init(const char* output_path, const char* workload);
void dependency_observer_init_from_env();
void dependency_observer_update_roi(bool wb_sign, uint64_t wb_pc);
void dependency_observer_begin_roi();
void dependency_observer_end_roi();
void dependency_observer_cycle();
void dependency_observer_sample(const DependencyObserverSample& sample);
int dependency_observer_finalize(int exit_status);

#endif
