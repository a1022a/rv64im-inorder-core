#include "VgolCache.h"
#include "verilated.h"
#include "dependency_observer.h"

#include <array>
#include <cctype>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {
constexpr uint32_t kMemoryBase = 0x80000000U;
constexpr size_t kMemoryBytes = 1048576;
constexpr uint32_t kEventAddress = 0xa0000100U;
constexpr uint32_t kPayloadAddress = 0xa0000108U;
constexpr uint64_t kWatchdogCycles = 10000000;

struct Counts {
  uint64_t cycles = 0;
  uint64_t values[34] = {};
};

const char* kNames[] = {
    "icache_accesses", "icache_hits", "icache_misses",
    "icache_refill_started_in_roi", "icache_refill_completed_in_roi",
    "icache_miss_stall_cycles", "icache_total_stall_cycles",
    "dcache_accesses", "dcache_load_accesses", "dcache_store_accesses",
    "dcache_hits", "dcache_misses", "dcache_load_hits",
    "dcache_load_misses", "dcache_store_hits", "dcache_store_misses",
    "dcache_refill_started_in_roi", "dcache_refill_completed_in_roi",
    "dcache_dirty_evictions", "dcache_writeback_started_in_roi",
    "dcache_writeback_completed_in_roi", "dcache_miss_stall_cycles",
    "dcache_writeback_stall_cycles", "dcache_total_stall_cycles",
    "exclusive_dcache_cycles", "exclusive_divider_cycles",
    "exclusive_branch_cycles", "exclusive_dependency_cycles",
    "exclusive_icache_cycles", "exclusive_other_cycles",
    "icache_miss_allocated_in_roi", "dcache_miss_allocated_in_roi",
    "reserved0", "reserved1"};

class Harness {
 public:
  Harness(const char* hex, const char* json, uint64_t checksum, uint64_t cycles,
          const char* trace)
      : json_(json), trace_(trace), expected_checksum_(checksum), expected_cycles_(cycles) {
    LoadHex(hex);
    dependency_observer_init(std::getenv("DEPENDENCY_PROFILE_OUT"),
                             std::getenv("PERF_WORKLOAD"));
    dependency_observer_end_roi();
    if (!trace_.empty()) {
      trace_file_.open(trace_);
      if (!trace_file_) throw std::runtime_error("cannot open trace output");
      trace_file_ << "sequence_number,simulation_cycle,phase,address,operation,wmask,rtl_hit,rtl_miss,rtl_dirty_eviction\n";
    }
  }

  int Run() {
    top_.clk = 0;
    top_.rstn = 0;
    Eval();
    for (int edge = 0; edge < 5; ++edge) Tick();
    top_.rstn = 1;
    Eval();
    while (!done_ && edges_ < kWatchdogCycles) Tick();
    for (int edge = 0; edge < 5; ++edge) Tick();
    const bool invariants = counts_.values[0] == counts_.values[1] + counts_.values[2] &&
        counts_.values[7] == counts_.values[8] + counts_.values[9] &&
        counts_.values[7] == counts_.values[10] + counts_.values[11] &&
        counts_.values[8] == counts_.values[12] + counts_.values[13] &&
        counts_.values[9] == counts_.values[14] + counts_.values[15];
    const bool cycles_valid = expected_cycles_ == 0 ? measured_cycles_ > 0
                                                     : measured_cycles_ == expected_cycles_;
    const bool functional = done_ && events_ == std::vector<uint64_t>{1,2,3,4,5,6} &&
        cycles_valid && checksum_ == expected_checksum_;
    WriteJson(invariants, functional);
    const int dependency_status = dependency_observer_finalize(functional ? 0 : 2);
    std::cout << "MARKER_EVENT_SEQUENCE=" << Sequence() << "\n";
    std::cout << "OBSERVED_CYCLES_PER_GENERATION=" << measured_cycles_ << "\n";
    std::cout << "COUNTER_SAMPLED_CYCLES=" << counts_.cycles << "\n";
    std::cout << "OBSERVED_CHECKSUM=" << checksum_ << "\n";
    std::cout << "CACHE_COUNTER_INVARIANTS=" << (invariants ? "PASS" : "FAIL") << "\n";
    std::cout << "CONTROLLED_TERMINATION=" << (functional ? "PASS" : "FAIL") << "\n";
    return invariants && functional && counts_.cycles == measured_cycles_ &&
        dependency_status == 0 ? 0 : 2;
  }

 private:
  void LoadHex(const char* path) {
    memory_.fill(0);
    std::ifstream input(path);
    if (!input) throw std::runtime_error("cannot open HEX");
    std::string token;
    size_t offset = 0;
    std::vector<uint64_t> cycle_csrs;
    while (std::getline(input, token)) {
      if (token.size() != 2 || !std::isxdigit(token[0]) || !std::isxdigit(token[1]) ||
          offset >= memory_.size()) throw std::runtime_error("invalid HEX");
      memory_[offset++] = static_cast<uint8_t>(std::stoul(token, nullptr, 16));
    }
    for (size_t byte = 0; byte + 3 < offset; byte += 4) {
      uint32_t word = memory_[byte] | memory_[byte+1] << 8 |
          memory_[byte+2] << 16 | memory_[byte+3] << 24;
      if ((word & 0xfffff07fU) == 0xc0002073U) cycle_csrs.push_back(kMemoryBase + byte);
    }
    if (cycle_csrs.size() != 4) throw std::runtime_error("unexpected csrr cycle count");
    roi_start_pc_ = cycle_csrs[2];
    roi_end_pc_ = cycle_csrs[3];
  }

  uint64_t Read64(uint32_t address) const {
    if (address < kMemoryBase || address > kMemoryBase + kMemoryBytes - 8) return 0;
    uint64_t value = 0;
    const size_t offset = address - kMemoryBase;
    for (unsigned byte = 0; byte < 8; ++byte)
      value |= static_cast<uint64_t>(memory_[offset + byte]) << (8 * byte);
    return value;
  }

  void Sample() {
    if (!roi_) return;
    ++counts_.cycles;
    dependency_observer_cycle();
    auto& value = counts_.values;
    value[0] += top_.perf_icache_access_event;
    value[1] += top_.perf_icache_hit_event;
    value[2] += top_.perf_icache_miss_event;
    value[3] += top_.perf_icache_miss_stall && !previous_icache_refill_;
    value[4] += !top_.perf_icache_miss_stall && previous_icache_refill_;
    value[5] += top_.perf_icache_miss_stall;
    value[6] += top_.perf_icache_total_stall;
    value[7] += top_.perf_dcache_access_event;
    value[8] += top_.perf_dcache_load_access_event;
    value[9] += top_.perf_dcache_store_access_event;
    value[10] += top_.perf_dcache_hit_event;
    value[11] += top_.perf_dcache_miss_event;
    value[12] += top_.perf_dcache_hit_event && top_.perf_dcache_load_access_event;
    value[13] += top_.perf_dcache_miss_event && top_.perf_dcache_load_access_event;
    value[14] += top_.perf_dcache_hit_event && top_.perf_dcache_store_access_event;
    value[15] += top_.perf_dcache_miss_event && top_.perf_dcache_store_access_event;
    value[16] += top_.perf_dcache_miss_stall && !previous_dcache_refill_;
    value[17] += !top_.perf_dcache_miss_stall && previous_dcache_refill_;
    value[18] += top_.perf_dcache_dirty_eviction_event;
    value[19] += top_.perf_dcache_writeback_stall && !previous_dcache_writeback_;
    value[20] += !top_.perf_dcache_writeback_stall && previous_dcache_writeback_;
    value[21] += top_.perf_dcache_miss_stall;
    value[22] += top_.perf_dcache_writeback_stall;
    value[23] += top_.perf_dcache_total_stall;
    value[30] += top_.perf_icache_miss_event;
    value[31] += top_.perf_dcache_miss_event;
    if (top_.perf_dcache_total_stall) ++value[24];
    else if (top_.perf_divider_stall) ++value[25];
    else if (top_.perf_branch_recovery) ++value[26];
    else if (top_.perf_dependency_stall) ++value[27];
    else if (top_.perf_icache_total_stall) ++value[28];
    else ++value[29];
    dependency_observer_sample({
        static_cast<bool>(top_.perf_dependency_stall),
        static_cast<bool>(top_.perf_dcache_total_stall),
        static_cast<bool>(top_.perf_divider_stall),
        static_cast<bool>(top_.perf_branch_recovery),
        static_cast<bool>(top_.perf_dcache_load_access_event),
        static_cast<bool>(top_.perf_dcache_hit_event),
        static_cast<bool>(top_.perf_dcache_miss_event),
        top_.perf_dcache_access_address,
        top_.perf_dependency_consumer_pc,
        top_.perf_dependency_consumer_inst,
        top_.perf_exu_pc,
        top_.perf_exu_inst,
        top_.perf_dependency_producer_rd,
        top_.perf_dependency_producer_address,
    });
  }

  void SampleTrace(const char* phase) {
    if (!trace_file_ || roi_completed_ || !top_.perf_dcache_access_event) return;
    trace_file_ << trace_sequence_++ << ',' << edges_ << ',' << phase << ",0x"
                << std::hex << std::setw(8) << std::setfill('0')
                << top_.perf_dcache_access_address << std::dec << ','
                << (top_.perf_dcache_store_access_event ? "STORE" : "LOAD") << ",0x"
                << std::hex << std::setw(2) << static_cast<unsigned>(top_.perf_dcache_access_wmask)
                << std::dec << ',' << static_cast<unsigned>(top_.perf_dcache_hit_event) << ','
                << static_cast<unsigned>(top_.perf_dcache_miss_event) << ','
                << static_cast<unsigned>(top_.perf_dcache_dirty_eviction_event) << '\n';
  }

  void CommitWrite() {
    if (!top_.axi_b_ready_o) return;
    if (write_address_ == kPayloadAddress) last_payload_ = write_data_;
    else if (write_address_ == kEventAddress) {
      events_.push_back(write_data_);
      if (write_data_ == 4) measured_cycles_ = last_payload_;
      if (write_data_ == 5) checksum_ = last_payload_;
      if (write_data_ == 6) done_ = true;
    } else if (write_address_ >= kMemoryBase && write_address_ < kMemoryBase + kMemoryBytes) {
      const size_t offset = write_address_ - kMemoryBase;
      for (unsigned byte = 0; byte < 8; ++byte)
        if ((write_strobes_ >> byte) & 1U)
          memory_[offset + byte] = static_cast<uint8_t>(write_data_ >> (8 * byte));
    }
  }

  void Drive() {
    top_.axi_aw_ready_i = top_.axi_aw_valid_o;
    top_.axi_w_ready_i = top_.axi_w_valid_o;
    top_.axi_b_valid_i = top_.axi_b_ready_o;
    top_.axi_ar_ready_i = top_.axi_ar_valid_o;
    top_.axi_r_valid_i = top_.axi_r_ready_o;
    top_.axi_r_data_i = Read64(read_address_);
    top_.axi_b_resp_i = 0; top_.axi_b_id_i = 0; top_.axi_b_user_i = 0;
    top_.axi_r_resp_i = 0; top_.axi_r_last_i = 1; top_.axi_r_id_i = 0;
    top_.axi_r_user_i = 0;
  }

  void Eval() { Drive(); top_.eval(); }
  void Tick() {
    top_.clk = 1; Eval(); ++edges_;
    const bool start = top_.perf_exu_active && top_.perf_exu_pc == roi_start_pc_;
    const bool stop = top_.perf_exu_active && top_.perf_exu_pc == roi_end_pc_;
    if (start) {
      SampleTrace("PRE_ROI");
      roi_ = true;
      dependency_observer_begin_roi();
    } else {
      SampleTrace(roi_ ? "ROI" : "PRE_ROI");
      Sample();
    }
    if (stop) {
      roi_ = false;
      roi_completed_ = true;
      dependency_observer_end_roi();
    }
    CommitWrite();
    read_address_ = top_.axi_ar_addr_o;
    write_address_ = top_.axi_aw_addr_o;
    write_data_ = top_.axi_w_data_o;
    write_strobes_ = top_.axi_w_strb_o;
    previous_icache_refill_ = top_.perf_icache_miss_stall;
    previous_dcache_refill_ = top_.perf_dcache_miss_stall;
    previous_dcache_writeback_ = top_.perf_dcache_writeback_stall;
    top_.clk = 0; Eval();
  }

  std::string Sequence() const {
    std::ostringstream out;
    for (size_t index = 0; index < events_.size(); ++index) {
      if (index) out << ',';
      out << events_[index];
    }
    return out.str();
  }

  void WriteJson(bool invariants, bool functional) const {
    std::ofstream out(json_);
    out << "{\n  \"schema_version\": \"a2-cache-c0-gol-v1\",\n";
    out << "  \"roi_cycles\": " << measured_cycles_ << ",\n";
    out << "  \"counter_sampled_cycles\": " << counts_.cycles << ",\n";
    for (size_t index = 0; index < 32; ++index)
      out << "  \"" << kNames[index] << "\": " << counts_.values[index] << ",\n";
    out << "  \"checksum\": " << checksum_ << ",\n";
    out << "  \"retirement_status\": \"NOT_QUALIFIED_UNAVAILABLE_AT_SYNTHESIS_TOP\",\n";
    out << "  \"counter_invariants_pass\": " << (invariants ? "true" : "false") << ",\n";
    out << "  \"functional_status\": \"" << (functional ? "PASS" : "FAIL") << "\"\n}\n";
  }

  VgolCache top_;
  std::array<uint8_t, kMemoryBytes> memory_{};
  std::string json_;
  std::string trace_;
  std::ofstream trace_file_;
  Counts counts_;
  std::vector<uint64_t> events_;
  uint64_t expected_checksum_, expected_cycles_, roi_start_pc_, roi_end_pc_;
  uint64_t measured_cycles_ = 0, checksum_ = 0, last_payload_ = 0, edges_ = 0;
  uint32_t read_address_ = 0, write_address_ = 0;
  uint64_t write_data_ = 0;
  uint8_t write_strobes_ = 0;
  uint64_t trace_sequence_ = 0;
  bool roi_ = false, done_ = false;
  bool roi_completed_ = false;
  bool previous_icache_refill_ = false;
  bool previous_dcache_refill_ = false;
  bool previous_dcache_writeback_ = false;
};
}  // namespace

int main(int argc, char** argv) {
  if (argc != 5 && argc != 6) return 64;
  Verilated::commandArgs(argc, argv);
  try {
    Harness harness(argv[1], argv[2], std::stoull(argv[3], nullptr, 0),
                    std::stoull(argv[4], nullptr, 0), argc == 6 ? argv[5] : "");
    return harness.Run();
  } catch (const std::exception& error) {
    std::cerr << "HARNESS_ERROR=" << error.what() << "\n";
    return 65;
  }
}
