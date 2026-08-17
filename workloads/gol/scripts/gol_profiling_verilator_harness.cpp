#include "VgolProfile.h"
#include "verilated.h"

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

class GolHarness {
 public:
  GolHarness(const std::string& hex_path, uint64_t expected_checksum,
             uint64_t expected_cycles)
      : expected_checksum_(expected_checksum), expected_cycles_(expected_cycles) {
    LoadHex(hex_path);
  }

  int Run() {
    top_.clk = 0;
    top_.rstn = 0;
    Evaluate();
    for (uint64_t reset_edge = 1; reset_edge <= 5; ++reset_edge) {
      RisingEdge();
      std::cout << "RESET_POSEDGE=" << reset_edge << "\n";
      FallingEdge();
    }
    top_.rstn = 1;
    Evaluate();
    std::cout << "RESET_DEASSERT_AFTER_POSEDGE=5\n";

    while (!done_ && rising_edges_ < kWatchdogCycles) {
      RisingEdge();
      FallingEdge();
    }
    if (!done_) {
      std::cerr << "SIMULATION_STATUS=FAIL_WATCHDOG\n";
      return 1;
    }
    for (unsigned int edge = 0; edge < 5; ++edge) {
      RisingEdge();
      FallingEdge();
    }

    std::cout << "DONE_POST_RISING_EDGES=5\n";
    std::cout << "MARKER_EVENT_SEQUENCE=" << EventSequence() << "\n";
    std::cout << "OBSERVED_CYCLES_PER_GENERATION=" << measured_cycles_ << "\n";
    std::cout << "OBSERVED_CHECKSUM=" << checksum_ << "\n";
    std::cout << "EXPECTED_CHECKSUM=" << expected_checksum_ << "\n";
    if (expected_cycles_ != 0) {
      std::cout << "EXPECTED_CYCLES_PER_GENERATION=" << expected_cycles_ << "\n";
    }
    std::cout << "DONE_SEEN=YES\n";
    std::cout << "CONTROLLED_TERMINATION=PASS\n";
    return events_ == std::vector<uint64_t>{1, 2, 3, 4, 5, 6} &&
                   (expected_cycles_ == 0 || measured_cycles_ == expected_cycles_) &&
                   checksum_ == expected_checksum_
               ? 0
               : 2;
  }

 private:
  void LoadHex(const std::string& hex_path) {
    memory_.fill(0);
    std::ifstream input(hex_path);
    if (!input) {
      throw std::runtime_error("cannot open HEX: " + hex_path);
    }
    std::string token;
    size_t offset = 0;
    while (std::getline(input, token)) {
      if (token.size() != 2 || !std::isxdigit(static_cast<unsigned char>(token[0])) ||
          !std::isxdigit(static_cast<unsigned char>(token[1])) || offset >= memory_.size()) {
        throw std::runtime_error("invalid or oversized byte-per-line HEX");
      }
      memory_[offset++] = static_cast<uint8_t>(std::stoul(token, nullptr, 16));
    }
    std::cout << "HEX_BYTES_LOADED=" << offset << "\n";
  }

  uint64_t Read64(uint32_t address) const {
    if (address < kMemoryBase || address > kMemoryBase + kMemoryBytes - 8) {
      return 0;
    }
    const size_t offset = address - kMemoryBase;
    uint64_t result = 0;
    for (unsigned int byte = 0; byte < 8; ++byte) {
      result |= static_cast<uint64_t>(memory_[offset + byte]) << (byte * 8);
    }
    return result;
  }

  void CommitWrite() {
    if (!top_.axi_b_ready_o) {
      return;
    }
    if (write_address_ == kPayloadAddress) {
      last_payload_ = write_data_;
      return;
    }
    if (write_address_ == kEventAddress) {
      const uint64_t event = write_data_;
      events_.push_back(event);
      std::cout << "MARKER event=" << event << " payload=" << last_payload_
                << " architectural_cycle_diagnostic=" << rising_edges_
                << " harness_edge_count=" << rising_edges_ << "\n";
      if (event == 4) measured_cycles_ = last_payload_;
      if (event == 5) checksum_ = last_payload_;
      if (event == 6) done_ = true;
      return;
    }
    if (write_address_ < kMemoryBase || write_address_ >= kMemoryBase + kMemoryBytes) {
      return;
    }
    const size_t offset = write_address_ - kMemoryBase;
    for (unsigned int byte = 0; byte < 8 && offset + byte < memory_.size(); ++byte) {
      if ((write_strobes_ >> byte) & 1U) {
        memory_[offset + byte] = static_cast<uint8_t>(write_data_ >> (byte * 8));
      }
    }
  }

  void DriveAxi() {
    top_.axi_aw_ready_i = top_.axi_aw_valid_o;
    top_.axi_w_ready_i = top_.axi_w_valid_o;
    top_.axi_b_valid_i = top_.axi_b_ready_o;
    top_.axi_ar_ready_i = top_.axi_ar_valid_o;
    top_.axi_r_valid_i = top_.axi_r_ready_o;
    top_.axi_r_data_i = Read64(read_address_);
    top_.axi_b_resp_i = 0;
    top_.axi_b_id_i = 0;
    top_.axi_b_user_i = 0;
    top_.axi_r_resp_i = 0;
    top_.axi_r_last_i = 1;
    top_.axi_r_id_i = 0;
    top_.axi_r_user_i = 0;
  }

  void Evaluate() {
    DriveAxi();
    top_.eval();
  }

  void RisingEdge() {
    top_.clk = 1;
    Evaluate();
    ++rising_edges_;
    CommitWrite();
    read_address_ = top_.axi_ar_addr_o;
    write_address_ = top_.axi_aw_addr_o;
    write_data_ = top_.axi_w_data_o;
    write_strobes_ = top_.axi_w_strb_o;
  }

  void FallingEdge() {
    top_.clk = 0;
    Evaluate();
  }

  std::string EventSequence() const {
    std::ostringstream output;
    for (size_t index = 0; index < events_.size(); ++index) {
      if (index != 0) output << ',';
      output << events_[index];
    }
    return output.str();
  }

  VgolProfile top_;
  std::array<uint8_t, kMemoryBytes> memory_{};
  uint32_t read_address_ = 0;
  uint32_t write_address_ = 0;
  uint64_t write_data_ = 0;
  uint8_t write_strobes_ = 0;
  uint64_t last_payload_ = 0;
  uint64_t measured_cycles_ = 0;
  uint64_t checksum_ = 0;
  uint64_t expected_checksum_ = 0;
  uint64_t expected_cycles_ = 0;
  uint64_t rising_edges_ = 0;
  bool done_ = false;
  std::vector<uint64_t> events_;
};
}  // namespace

int main(int argc, char** argv) {
  if (argc != 3 && argc != 4) {
    std::cerr << "usage: gol_profiling_verilator_harness HEX EXPECTED_CHECKSUM [EXPECTED_CYCLES]\n";
    return 64;
  }
  Verilated::commandArgs(argc, argv);
  try {
    const uint64_t expected_checksum = std::stoull(argv[2], nullptr, 0);
    const uint64_t expected_cycles = argc == 4 ? std::stoull(argv[3], nullptr, 0) : 0;
    GolHarness harness(argv[1], expected_checksum, expected_cycles);
    return harness.Run();
  } catch (const std::exception& error) {
    std::cerr << "HARNESS_ERROR=" << error.what() << "\n";
    return 65;
  }
}
