#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source scripts/lib/config.sh

OUT_DIR="out/perf_roi_retire"
BUILD_DIR="${OUT_DIR}/build"
LOG_DIR="out/logs/perf_roi_retire"
ELF="${OUT_DIR}/perf_roi_retire.elf"
BIN="${OUT_DIR}/perf_roi_retire.bin"
RAW="${OUT_DIR}/perf_roi_retire.json"
LOG="${LOG_DIR}/perf_roi_retire.log"

mkdir -p "${BUILD_DIR}" "${LOG_DIR}"
test -n "${NEMU_REF_SO}"
test -f "${NEMU_REF_SO}"

riscv64-linux-gnu-gcc -nostdlib -nostartfiles -static -fno-pic -fno-pie \
  -no-pie -march=rv64im -mabi=lp64 -Wl,--build-id=none -Wl,--no-relax \
  -T tests/custom/perf_roi_retire.ld -o "${ELF}" tests/custom/perf_roi_retire.S
riscv64-linux-gnu-objcopy -O binary "${ELF}" "${BIN}"
riscv64-linux-gnu-objdump -d "${ELF}" > "${LOG_DIR}/perf_roi_retire.dis"

symbol_addr() {
  riscv64-linux-gnu-nm -n "${ELF}" | awk -v symbol="$1" '$3 == symbol { print "0x" $1; exit }'
}

ROI_START="$(symbol_addr perf_roi_start)"
ROI_END="$(symbol_addr perf_roi_end)"
test -n "${ROI_START}"
test -n "${ROI_END}"

mapfile -t csrcs < <(find "${ROOT_DIR}/sim/csrc" -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) | sort)
verilator --cc --trace --exe --build "${csrcs[@]}" -f ./rtl/filelists/sim.f \
  -I./rtl/vsrc -top rv64im_core_sim_top --prefix Vtop --Mdir "${BUILD_DIR}" \
  -CFLAGS "-I${ROOT_DIR}/sim/csrc/include" -CFLAGS -ggdb -CFLAGS -O2 \
  -CFLAGS "-I$(llvm-config --includedir)" -CFLAGS -std=c++14 -CFLAGS -fno-exceptions \
  -CFLAGS -D_GNU_SOURCE -CFLAGS -D__STDC_CONSTANT_MACROS -CFLAGS -D__STDC_FORMAT_MACROS \
  -CFLAGS -D__STDC_LIMIT_MACROS -CFLAGS -fPIE -LDFLAGS -lLLVM-12 -LDFLAGS -lreadline \
  -LDFLAGS -ldl -LDFLAGS -pie -LDFLAGS -fsanitize=address -LDFLAGS -lSDL2 > "${LOG}" 2>&1

PERF_RAW_OUT="${RAW}" PERF_WORKLOAD=perf_roi_retire PERF_GIT_COMMIT="$(git rev-parse HEAD)" \
  PERF_ROI_START_PC="${ROI_START}" PERF_ROI_END_PC="${ROI_END}" \
  ASAN_OPTIONS=detect_leaks=0 "${BUILD_DIR}/Vtop" -d "${NEMU_REF_SO}" -b -f "${ELF}" "${BIN}" >> "${LOG}" 2>&1

EXPECTED_SYMBOLS=(perf_roi_lead0 perf_roi_lead1 perf_roi_lead2 perf_roi_lead3 perf_roi_lead4 perf_roi_lead5 \
  perf_roi_addi perf_roi_forward perf_roi_store perf_roi_load perf_roi_load_use perf_roi_div perf_roi_branch_not_taken \
  perf_roi_branch_taken perf_roi_jal perf_roi_jalr_base perf_roi_jalr_addr perf_roi_jalr perf_roi_csr perf_roi_result perf_roi_drain0 perf_roi_drain1 perf_roi_drain2 \
  perf_roi_drain3 perf_roi_drain4)
EXPECTED_PCS="$(IFS=,; for symbol in "${EXPECTED_SYMBOLS[@]}"; do symbol_addr "${symbol}"; done | paste -sd, -)"

WRONG_PATH_PCS="$(IFS=,; for symbol in perf_roi_wrong_path perf_roi_jal_wrong_path perf_roi_jalr_wrong_path; do symbol_addr "${symbol}"; done | paste -sd, -)"
CONDITIONAL_BRANCH_PCS="$(IFS=,; for symbol in perf_roi_branch_not_taken perf_roi_branch_taken; do symbol_addr "${symbol}"; done | paste -sd, -)"
export WRONG_PATH_PCS

perl -MJSON::PP -e '
  my ($path, $expected, $conditional_branch_pcs) = @ARGV;
  open my $fh, "<", $path or die "$path: $!";
  local $/; my $json = decode_json(<$fh>);
  die "ROI is not valid\n" unless $json->{measurement_scope} eq "pc_marker_roi" && $json->{roi_valid};
  die "unexpected exit\n" unless $json->{exit_status} == 0;
  my @want = split /,/, $expected;
  my @got = map { sprintf("0x%016x", hex($_->{wb_pc})) } @{$json->{observations}};
  die "writeback sequence mismatch\nwant: @want\ngot: @got\n" unless "@want" eq "@got";
  die "divider wait absent\n" unless $json->{divider_wait_cycles} > 0;
  die "D-cache miss absent\n" unless $json->{dcache_miss_observation_count} > 0;
  die "load-use stall absent\n" unless $json->{load_use_stall_cycles} > 0;
  die "branch resolution count too small\n" unless $json->{branch_resolved_observation_count} >= 4;
  die "branch direction error absent\n" unless $json->{branch_direction_error_count} > 0;
  die "branch flush absent\n" unless $json->{flush_branch_count} > 0;
  die "branch recovery episode semantics changed\n" unless $json->{branch_recovery_episode_count} == 2;
  die "conditional direction recovery absent\n" unless $json->{conditional_direction_recovery_episode_count} > 0;
  die "JALR target recovery absent\n" unless $json->{jalr_target_recovery_episode_count} > 0;
  die "unexpected other recovery\n" unless $json->{other_recovery_episode_count} == 0;
  die "directed recovery subtype accounting mismatch\n" unless
    $json->{conditional_direction_recovery_episode_count} +
    $json->{jalr_target_recovery_episode_count} +
    $json->{other_recovery_episode_count} == $json->{branch_recovery_episode_count};
  die "dependency bubble/stall absent\n" unless $json->{dependency_stall_cycles} > 0;
  die "exclusive cycle sum mismatch\n" unless $json->{exclusive_cycle_sum_matches_roi};
  my @want_conditional = split /,/, $conditional_branch_pcs;
  my @got_conditional = map { sprintf("0x%016x", hex($_->{pc})) } @{$json->{conditional_branch_observations}};
  for my $conditional_pc (@want_conditional) {
    die "conditional branch resolution missing: $conditional_pc\n" unless grep { $_ eq sprintf("0x%016x", hex($conditional_pc)) } @got_conditional;
  }
  for my $wrong_pc (split /,/, $ENV{WRONG_PATH_PCS}) {
    die "wrong-path instruction observed: $wrong_pc\n" if grep { $_ eq sprintf("0x%016x", hex($wrong_pc)) } @got;
  }
  die "wait exceeds ROI cycles\n" if $json->{icache_wait_cycles} > $json->{simulator_cycle_count} || $json->{dcache_memory_wait_cycles} > $json->{simulator_cycle_count};
' "${RAW}" "${EXPECTED_PCS}" "${CONDITIONAL_BRANCH_PCS}"

grep -q 'HIT GOOD TRAP' "${LOG}"
if grep -Eiq 'fatal|mismatch|ABORT|bad trap|BAD TRAP|AddressSanitizer|assert|non-convergence' "${LOG}"; then
  exit 1
fi

echo "PERF_ROI_RETIRE_DIRECTED=PASS"
