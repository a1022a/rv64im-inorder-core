#include "VdividerDrc1.h"
#include "verilated.h"

#include <cinttypes>
#include <cstdint>
#include <cstdio>
#include <limits>
#include <random>
#include <vector>

namespace {
struct TestCase {
  uint64_t dividend;
  uint64_t divisor;
  bool is_signed;
  bool hold_ready;
};

uint64_t magnitude(uint64_t value) {
  return (value >> 63) ? (~value + 1U) : value;
}

uint64_t expected_quotient(const TestCase& test) {
  if (test.divisor == 0) return UINT64_MAX;
  if (!test.is_signed) return test.dividend / test.divisor;
  const bool negative = ((test.dividend ^ test.divisor) >> 63) != 0;
  const uint64_t quotient = magnitude(test.dividend) / magnitude(test.divisor);
  return negative ? (~quotient + 1U) : quotient;
}

uint64_t expected_remainder(const TestCase& test) {
  if (test.divisor == 0) return test.dividend;
  if (!test.is_signed) return test.dividend % test.divisor;
  const uint64_t remainder = magnitude(test.dividend) % magnitude(test.divisor);
  return (test.dividend >> 63) ? (~remainder + 1U) : remainder;
}

void clock(VdividerDrc1* top) {
  top->clk = 0;
  top->eval();
  top->clk = 1;
  top->eval();
}

void add_fixed_cases(std::vector<TestCase>* tests) {
  const uint64_t values[] = {
      0, 1, UINT64_MAX, 2, 3, 7, 11, 0x7fffffffffffffffULL,
      0x8000000000000000ULL, 0xfffffffffffffffbULL, 0xfffffffffffffff9ULL,
      0xffffffff00000000ULL, 0x00000000ffffffffULL};
  for (bool is_signed : {false, true}) {
    for (uint64_t dividend : values) {
      for (uint64_t divisor : values) {
        tests->push_back({dividend, divisor, is_signed,
                          ((dividend ^ divisor) & 7U) == 0});
      }
    }
  }
  tests->push_back({0x8000000000000000ULL, UINT64_MAX, true, true});
  tests->push_back({5, 11, true, true});
  tests->push_back({11, 11, true, false});
  tests->push_back({12, 11, true, false});
}
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  VdividerDrc1 top;
  top.clk = 0;
  top.rstn = 0;
  top.i_alu_div_req = 0;
  top.i_stall = 0;
  top.rs1 = 0;
  top.rs2 = 0;
  top.is_signed = 0;
  for (int cycle = 0; cycle < 3; ++cycle) clock(&top);
  top.rstn = 1;

  std::vector<TestCase> tests;
  add_fixed_cases(&tests);
  std::mt19937_64 random(0x445243315032ULL);
  for (unsigned index = 0; index < 512; ++index) {
    tests.push_back({random(), random(), (index & 1U) != 0, (index % 31U) == 0});
  }

  std::puts("index,signed,dividend,divisor,ack_cycles,held_cycles,quotient,remainder");
  for (size_t index = 0; index < tests.size(); ++index) {
    const TestCase& test = tests[index];
    top.rs1 = test.dividend;
    top.rs2 = test.divisor;
    top.is_signed = test.is_signed;
    top.i_alu_div_req = 1;
    clock(&top);
    top.i_alu_div_req = 0;

    uint64_t ack_cycles = 0;
    while (!top.o_alu_div_ack && ack_cycles < 70) {
      clock(&top);
      ++ack_cycles;
    }
    if (!top.o_alu_div_ack || top.div_res != expected_quotient(test) ||
        top.div_rem != expected_remainder(test)) {
      std::fprintf(stderr, "divider mismatch at case %zu\n", index);
      return 1;
    }

    unsigned held_cycles = test.hold_ready ? 3U : 0U;
    top.i_stall = test.hold_ready;
    for (unsigned held = 0; held < held_cycles; ++held) {
      const uint64_t quotient = top.div_res;
      const uint64_t remainder = top.div_rem;
      clock(&top);
      if (!top.o_alu_div_ack || top.div_res != quotient || top.div_rem != remainder) {
        std::fprintf(stderr, "ready hold mismatch at case %zu\n", index);
        return 2;
      }
    }
    top.i_stall = 0;
    const uint64_t quotient = top.div_res;
    const uint64_t remainder = top.div_rem;
    std::printf("%zu,%u,%016" PRIx64 ",%016" PRIx64 ",%" PRIu64
                ",%u,%016" PRIx64 ",%016" PRIx64 "\n",
                index, test.is_signed, test.dividend, test.divisor, ack_cycles,
                held_cycles, quotient, remainder);
    clock(&top);
    if (top.o_alu_div_ack) return 3;
  }

  top.final();
  return 0;
}
