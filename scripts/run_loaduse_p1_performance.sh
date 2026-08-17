#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source scripts/lib/config.sh

OUT_DIR="out/loaduse_p1_perf"
SIM_BUILD_DIR="${OUT_DIR}/sim_build"
GOL_BUILD_DIR="${OUT_DIR}/gol_build"
RESULT_DIR="${OUT_DIR}/results"
LOG_DIR="${OUT_DIR}/logs"
NEMU_SO="${NEMU_REF_SO}"
AM_DIR="${AM_KERNELS_DIR}"
: "${GOL_WORKLOAD_DIR:?set GOL_WORKLOAD_DIR to a generated GOL workload directory}"
GOL_DIR="${GOL_WORKLOAD_DIR}"

mkdir -p "${SIM_BUILD_DIR}" "${GOL_BUILD_DIR}" "${RESULT_DIR}" "${LOG_DIR}"
test -f "${NEMU_SO}"
test -d "${AM_DIR}"

mapfile -t csrcs < <(find "${ROOT_DIR}/sim/csrc" -type f \
  \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) | sort)
verilator --cc --trace --exe --build -Wno-PINMISSING "${csrcs[@]}" -f rtl/filelists/sim.f \
  -Irtl/vsrc -top rv64im_core_sim_top --prefix Vtop --Mdir "${SIM_BUILD_DIR}" \
  -DPERFORMANCE_MODEL -CFLAGS "-I${ROOT_DIR}/sim/csrc/include" -CFLAGS -ggdb \
  -CFLAGS -DPERFORMANCE_MODEL -CFLAGS -O2 \
  -CFLAGS "-I$(llvm-config --includedir)" -CFLAGS -std=c++14 \
  -CFLAGS -fno-exceptions -CFLAGS -D_GNU_SOURCE \
  -CFLAGS -D__STDC_CONSTANT_MACROS -CFLAGS -D__STDC_FORMAT_MACROS \
  -CFLAGS -D__STDC_LIMIT_MACROS -CFLAGS -fPIE -LDFLAGS -lLLVM-12 \
  -LDFLAGS -lreadline -LDFLAGS -ldl -LDFLAGS -pie \
  -LDFLAGS -fsanitize=address -LDFLAGS -lSDL2 \
  > "${LOG_DIR}/sim_build.log" 2>&1

run_pc_roi() {
  local workload="$1"
  local start_pc="$2"
  local end_pc="$3"
  local elf="$4"
  local bin="$5"
  local log="${LOG_DIR}/${workload}.log"
  local json="${RESULT_DIR}/${workload}.json"

  DEPENDENCY_PROFILE_OUT="${json}" PERF_WORKLOAD="${workload}" \
    PERF_ROI_START_PC="${start_pc}" PERF_ROI_END_PC="${end_pc}" \
    ASAN_OPTIONS=detect_leaks=0 "${SIM_BUILD_DIR}/Vtop" \
    -d "${NEMU_SO}" -b -f "${elf}" "${bin}" > "${log}" 2>&1
  grep -q 'HIT GOOD TRAP' "${log}"
  if grep -Eiq 'fatal|mismatch|ABORT|bad trap|BAD TRAP|AddressSanitizer|assert|non-convergence' "${log}"; then
    return 1
  fi
}

run_pc_roi microbench_fib 0x80003150 0x80004a94 \
  "${AM_DIR}/benchmarks/microbench/build/microbench-riscv64-npc.elf" \
  "${AM_DIR}/benchmarks/microbench/build/microbench-riscv64-npc.bin"
run_pc_roi cpu_bubble_sort 0x80000028 0x800000a0 \
  "${AM_DIR}/tests/cpu-tests/build/bubble-sort-riscv64-npc.elf" \
  "${AM_DIR}/tests/cpu-tests/build/bubble-sort-riscv64-npc.bin"

verilator --cc --exe --build --top-module rv64im_core_top --prefix VgolCache \
  --Mdir "${GOL_BUILD_DIR}" -DPERFORMANCE_MODEL -Irtl/vsrc \
  -f rtl/filelists/synth.f "${ROOT_DIR}/models/loaduse_p1/gol_profile_harness.cpp" \
  "${ROOT_DIR}/sim/csrc/dependency_observer.cpp" -CFLAGS "-I${ROOT_DIR}/sim/csrc" \
  > "${LOG_DIR}/gol_build.log" 2>&1

run_gol() {
  local workload="$1"
  local size="$2"
  local checksum="$3"
  local cache_json="${RESULT_DIR}/${workload}_cache.json"
  local dependency_json="${RESULT_DIR}/${workload}.json"
  local log="${LOG_DIR}/${workload}.log"

  DEPENDENCY_PROFILE_OUT="${dependency_json}" PERF_WORKLOAD="${workload}" \
    "${GOL_BUILD_DIR}/VgolCache" "${GOL_DIR}/images/program_${size}x${size}.hex" \
    "${cache_json}" "${checksum}" 0 > "${log}" 2>&1
  grep -q 'CONTROLLED_TERMINATION=PASS' "${log}"
  grep -q "OBSERVED_CHECKSUM=${checksum}" "${log}"
}

run_gol gol128 128 3844
run_gol gol256 256 15876

perl -MJSON::PP -e '
  my ($result_dir) = @ARGV;
  my %expected_checksum = (gol128 => 3844, gol256 => 15876);
  for my $workload (qw(microbench_fib cpu_bubble_sort gol128 gol256)) {
    open my $fh, "<", "$result_dir/$workload.json" or die "$workload: $!";
    local $/; my $json = decode_json(<$fh>);
    die "$workload invalid ROI\n" unless $json->{roi_valid};
    die "$workload non-positive ROI\n" unless $json->{roi_cycles} > 0;
    die "$workload unresolved load outcome\n" unless $json->{unresolved_load_outcomes} == 0;
    if (exists $expected_checksum{$workload}) {
      open my $cfh, "<", "$result_dir/${workload}_cache.json" or die "$workload cache: $!";
      local $/; my $cache = decode_json(<$cfh>);
      die "$workload checksum mismatch\n" unless $cache->{checksum} == $expected_checksum{$workload};
      die "$workload cycle accounting mismatch\n" unless
        $cache->{roi_cycles} == $json->{roi_cycles} &&
        $cache->{counter_sampled_cycles} == $cache->{roi_cycles};
      die "$workload functional failure\n" unless $cache->{functional_status} eq "PASS";
    }
    print uc($workload), "_ROI_CYCLES=", $json->{roi_cycles}, "\n";
    print uc($workload), "_LOAD_USE_STALL_CYCLES=", $json->{load_use_stall_cycles}, "\n";
    print uc($workload), "_LOAD_HIT_USE_STALL_CYCLES=", $json->{load_hit_use_stall_cycles}, "\n";
  }
' "${RESULT_DIR}" | tee "${RESULT_DIR}/summary.txt"

echo 'LOADUSE_P1_PERFORMANCE=PASS'
