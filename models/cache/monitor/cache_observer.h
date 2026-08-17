#ifndef RV64IM_CORE_CACHE_OBSERVER_H
#define RV64IM_CORE_CACHE_OBSERVER_H

#include <cstdint>

struct CacheObserverSample {
  uint8_t icache_access;
  uint8_t icache_hit;
  uint8_t icache_miss;
  uint8_t icache_refill_start;
  uint8_t icache_refill_complete;
  uint8_t icache_miss_stall;
  uint8_t icache_total_stall;
  uint8_t dcache_access;
  uint8_t dcache_load_access;
  uint8_t dcache_store_access;
  uint8_t dcache_hit;
  uint8_t dcache_miss;
  uint8_t dcache_refill_start;
  uint8_t dcache_refill_complete;
  uint8_t dcache_dirty_eviction;
  uint8_t dcache_writeback_start;
  uint8_t dcache_writeback_complete;
  uint8_t dcache_miss_stall;
  uint8_t dcache_writeback_stall;
  uint8_t dcache_total_stall;
  uint32_t dcache_address;
  uint8_t dcache_wmask;
  uint8_t branch_recovery;
  uint8_t dependency;
  uint8_t divider;
};

void cache_observer_init();
void cache_observer_update_roi(bool wb_sign, uint64_t wb_pc);
void cache_observer_cycle();
void cache_observer_sample(const CacheObserverSample& sample);
void cache_observer_sample_writeback(bool wb_sign, uint64_t wb_pc);
int cache_observer_finalize(int exit_status);

#endif
