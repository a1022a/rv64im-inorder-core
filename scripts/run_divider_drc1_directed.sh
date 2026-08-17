#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${P1_REFERENCE_DIR:?set P1_REFERENCE_DIR to the frozen load-use P1 checkout}"
P1_DIR="${P1_REFERENCE_DIR}"
cd "${ROOT_DIR}"

source scripts/lib/config.sh

OUT_DIR="out/divider_drc1_directed"
LOG_DIR="out/logs/divider_drc1_directed"
P1_BUILD_DIR="${OUT_DIR}/p1_div_build"
P2_BUILD_DIR="${OUT_DIR}/p2_div_build"
P1_SIM_BUILD_DIR="${OUT_DIR}/p1_sim_build"
P2_SIM_BUILD_DIR="${OUT_DIR}/p2_sim_build"
P1_NODIFF_BUILD_DIR="${OUT_DIR}/p1_nodiff_build"
P2_NODIFF_BUILD_DIR="${OUT_DIR}/p2_nodiff_build"
ELF="${OUT_DIR}/divider_drc1_directed.elf"
BIN="${OUT_DIR}/divider_drc1_directed.bin"
W_ELF="${OUT_DIR}/divider_drc1_w_directed.elf"
W_BIN="${OUT_DIR}/divider_drc1_w_directed.bin"

mkdir -p "${OUT_DIR}" "${LOG_DIR}"
test -f "${P1_DIR}/rtl/vsrc/exu/rv64im_core_div.sv"
test -f "${NEMU_REF_SO}"

build_divider() {
  local source_dir="$1"
  local build_dir="$2"
  local log="$3"
  verilator --cc --exe --build --top-module rv64im_core_div --prefix VdividerDrc1 \
    --Mdir "${build_dir}" "${source_dir}/rtl/vsrc/exu/rv64im_core_div.sv" \
    "${ROOT_DIR}/tests/custom/divider_drc1_tb.cpp" -CFLAGS -O2 > "${log}" 2>&1
}

build_simulator() {
  local source_dir="$1"
  local build_dir="$2"
  local log="$3"
  local difftest="$4"
  local include_flags="-I${source_dir}/sim/csrc/include"
  if [[ "${difftest}" == "no" ]]; then
    local nodiff_include="${ROOT_DIR}/${build_dir}/nodiff_include"
    mkdir -p "${nodiff_include}"
    cp -a "${source_dir}/sim/csrc/include/." "${nodiff_include}/"
    sed -i 's/^#define CONFIG_DIFFTEST 1$/#define CONFIG_DIFFTEST 0/' \
      "${nodiff_include}/config.h"
    include_flags="-I${nodiff_include} ${include_flags}"
  fi
  mapfile -t csrcs < <(find "${source_dir}/sim/csrc" -type f \
    \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) | sort)
  (
    cd "${source_dir}"
    verilator --cc --trace --exe --build "${csrcs[@]}" -f rtl/filelists/sim.f \
      -Irtl/vsrc -top rv64im_core_sim_top --prefix Vtop --Mdir "${ROOT_DIR}/${build_dir}" \
      -CFLAGS "${include_flags}" -CFLAGS -ggdb -CFLAGS -O2 \
      -CFLAGS "-I$(llvm-config --includedir)" -CFLAGS -std=c++14 \
      -CFLAGS -fno-exceptions -CFLAGS -D_GNU_SOURCE \
      -CFLAGS -D__STDC_CONSTANT_MACROS -CFLAGS -D__STDC_FORMAT_MACROS \
      -CFLAGS -D__STDC_LIMIT_MACROS -CFLAGS -fPIE \
      -LDFLAGS -lLLVM-12 -LDFLAGS -lreadline -LDFLAGS -ldl -LDFLAGS -pie \
      -LDFLAGS -fsanitize=address -LDFLAGS -lSDL2
  ) > "${log}" 2>&1
}

build_divider "${P1_DIR}" "${P1_BUILD_DIR}" "${LOG_DIR}/p1_div_build.log"
build_divider "${ROOT_DIR}" "${P2_BUILD_DIR}" "${LOG_DIR}/p2_div_build.log"
"${P1_BUILD_DIR}/VdividerDrc1" > "${OUT_DIR}/p1_results.csv"
"${P2_BUILD_DIR}/VdividerDrc1" > "${OUT_DIR}/p2_results.csv"
cmp "${OUT_DIR}/p1_results.csv" "${OUT_DIR}/p2_results.csv"

riscv64-linux-gnu-gcc -nostdlib -nostartfiles -static -fno-pic -fno-pie \
  -no-pie -march=rv64im -mabi=lp64 -Wl,--build-id=none -Wl,--no-relax \
  -T tests/custom/divider_drc1_directed.ld -o "${ELF}" \
  tests/custom/divider_drc1_directed.S
riscv64-linux-gnu-objcopy -O binary "${ELF}" "${BIN}"
riscv64-linux-gnu-objdump -d "${ELF}" > "${LOG_DIR}/divider_drc1_directed.dis"
riscv64-linux-gnu-gcc -nostdlib -nostartfiles -static -fno-pic -fno-pie \
  -no-pie -march=rv64im -mabi=lp64 -Wl,--build-id=none -Wl,--no-relax \
  -T tests/custom/divider_drc1_directed.ld -o "${W_ELF}" \
  tests/custom/divider_drc1_w_directed.S
riscv64-linux-gnu-objcopy -O binary "${W_ELF}" "${W_BIN}"
riscv64-linux-gnu-objdump -d "${W_ELF}" > "${LOG_DIR}/divider_drc1_w_directed.dis"

build_simulator "${P1_DIR}" "${P1_SIM_BUILD_DIR}" "${LOG_DIR}/p1_sim_build.log" yes
build_simulator "${ROOT_DIR}" "${P2_SIM_BUILD_DIR}" "${LOG_DIR}/p2_sim_build.log" yes
build_simulator "${P1_DIR}" "${P1_NODIFF_BUILD_DIR}" "${LOG_DIR}/p1_nodiff_build.log" no
build_simulator "${ROOT_DIR}" "${P2_NODIFF_BUILD_DIR}" "${LOG_DIR}/p2_nodiff_build.log" no

for version in p1 p2; do
  env ASAN_OPTIONS=detect_leaks=0 "${OUT_DIR}/${version}_sim_build/Vtop" \
    -d "${NEMU_REF_SO}" -b -f "${ELF}" "${BIN}" \
    > "${LOG_DIR}/${version}_integration.log" 2>&1
  grep -q 'HIT GOOD TRAP' "${LOG_DIR}/${version}_integration.log"
  if grep -Eiq 'fatal|mismatch|ABORT|bad trap|BAD TRAP|AddressSanitizer|assert|non-convergence' \
      "${LOG_DIR}/${version}_integration.log"; then
    exit 1
  fi
done

for version in p1 p2; do
  env ASAN_OPTIONS=detect_leaks=0 "${OUT_DIR}/${version}_nodiff_build/Vtop" \
    -b -f "${W_ELF}" "${W_BIN}" > "${LOG_DIR}/${version}_w_integration.log" 2>&1
  grep -q 'HIT GOOD TRAP' "${LOG_DIR}/${version}_w_integration.log"
  if grep -Eiq 'fatal|mismatch|ABORT|bad trap|BAD TRAP|AddressSanitizer|assert|non-convergence' \
      "${LOG_DIR}/${version}_w_integration.log"; then
    exit 1
  fi
done

test "$(wc -l < "${OUT_DIR}/p2_results.csv")" -gt 800
echo 'DIVIDER_DIRECTED_STATUS=PASS'
echo 'DIVIDER_DIRECTED_EQUIVALENCE=PASS'
