#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source scripts/lib/config.sh

OUT_DIR="out/loaduse_p1_directed"
BUILD_DIR="${OUT_DIR}/build"
LOG_DIR="out/logs/loaduse_p1_directed"
ELF="${OUT_DIR}/loaduse_p1_directed.elf"
BIN="${OUT_DIR}/loaduse_p1_directed.bin"
LOG="${LOG_DIR}/loaduse_p1_directed.log"

mkdir -p "${BUILD_DIR}" "${LOG_DIR}"
test -n "${NEMU_REF_SO}"
test -f "${NEMU_REF_SO}"

riscv64-linux-gnu-gcc -nostdlib -nostartfiles -static -fno-pic -fno-pie \
  -no-pie -march=rv64im -mabi=lp64 \
  -Wl,--build-id=none -Wl,--no-relax \
  -T tests/custom/loaduse_p1_directed.ld \
  -o "${ELF}" tests/custom/loaduse_p1_directed.S
riscv64-linux-gnu-objcopy -O binary "${ELF}" "${BIN}"
riscv64-linux-gnu-objdump -d "${ELF}" > "${LOG_DIR}/loaduse_p1_directed.dis"

mapfile -t csrcs < <(find "${ROOT_DIR}/sim/csrc" -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) | sort)
verilator --cc --trace --exe --build "${csrcs[@]}" -f ./rtl/filelists/sim.f \
  -I./rtl/vsrc -top rv64im_core_sim_top --prefix Vtop --Mdir "${BUILD_DIR}" \
  -DLOADUSE_P1_MONITOR \
  -CFLAGS "-I${ROOT_DIR}/sim/csrc/include" -CFLAGS -ggdb -CFLAGS -O2 \
  -CFLAGS "-I$(llvm-config --includedir)" -CFLAGS -std=c++14 \
  -CFLAGS -fno-exceptions -CFLAGS -D_GNU_SOURCE -CFLAGS -D__STDC_CONSTANT_MACROS \
  -CFLAGS -D__STDC_FORMAT_MACROS -CFLAGS -D__STDC_LIMIT_MACROS -CFLAGS -fPIE \
  -CFLAGS -DLOADUSE_P1_MONITOR \
  -LDFLAGS -lLLVM-12 -LDFLAGS -lreadline -LDFLAGS -ldl -LDFLAGS -pie \
  -LDFLAGS -fsanitize=address -LDFLAGS -lSDL2 > "${LOG}" 2>&1

env ASAN_OPTIONS=detect_leaks=0 "${BUILD_DIR}/Vtop" -d "${NEMU_REF_SO}" -b -f "${ELF}" "${BIN}" >> "${LOG}" 2>&1

grep -q 'HIT GOOD TRAP' "${LOG}"
grep -Eq '^LOADUSE_P1_HIT_BYPASS_EVENTS=[1-9][0-9]*$' "${LOG}"
grep -Eq '^LOADUSE_P1_MISS_HAZARD_EVENTS=[1-9][0-9]*$' "${LOG}"
grep -Eq '^LOADUSE_P1_OPERAND_BYPASS_EVENTS=[1-9][0-9]*$' "${LOG}"
if grep -Eiq 'fatal|mismatch|ABORT|bad trap|BAD TRAP|AddressSanitizer|assert|non-convergence' "${LOG}"; then
  exit 1
fi

echo "LOADUSE_P1_DIRECTED=PASS"
