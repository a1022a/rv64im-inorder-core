#include <cstdio>

#include "Vintr_directed_top.h"
#include "verilated.h"

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Vintr_directed_top top;
  bool checked_mret = false;
  bool failed_mret = false;
  unsigned long long mret_addr = 0;
  unsigned int mret_en = 0;

  for (int cycle = 0; cycle < 512 && !top.done; ++cycle) {
    top.clk = 0;
    top.eval();
    top.eval();
    if (top.mret_check_phase) {
      checked_mret = true;
      mret_en = top.mret_check_flush_en;
      mret_addr = static_cast<unsigned long long>(top.mret_check_flush_addr);
      failed_mret = !top.mret_check_flush_en ||
                    top.mret_check_flush_addr != 0x80000203ULL;
      if (failed_mret) {
        break;
      }
    }
    top.clk = 1;
    top.eval();
    top.eval();
  }

  if (top.done && !top.fail && checked_mret && !failed_mret) {
    return 0;
  }

  std::printf("intr_directed failed: done=%u fail=%u state=%u observed=0x%016llx "
              "checked_mret=%u failed_mret=%u mret_en=%u mret_addr=0x%016llx\n",
              top.done, top.fail, top.failed_state,
              static_cast<unsigned long long>(top.observed),
              checked_mret, failed_mret, mret_en, mret_addr);
  return 1;
}
