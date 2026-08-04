#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source scripts/lib/config.sh

LOG_DIR="out/logs/regress"
ARTIFACT_DIR="out/regress"
mkdir -p "${LOG_DIR}" "${ARTIFACT_DIR}"

if [[ -z "${NEMU_REF_SO}" || ! -f "${NEMU_REF_SO}" ]]; then
  echo "NEMU_REF_SO is not configured or missing: ${NEMU_REF_SO}" >&2
  exit 1
fi
if [[ -z "${AM_KERNELS_DIR}" || ! -d "${AM_KERNELS_DIR}" ]]; then
  echo "AM_KERNELS_DIR is not configured or missing: ${AM_KERNELS_DIR}" >&2
  exit 1
fi

run_image() {
  local category="$1"
  local name="$2"
  local bin="$3"
  local timeout_sec="${4:-${REGRESS_TIMEOUT_SEC}}"
  local log="${LOG_DIR}/${category}-${name}.log"
  local status=0

  if [[ ! -f "${bin}" ]]; then
    echo "missing image: ${bin}" >&2
    return 1
  fi

  timeout "${timeout_sec}s" \
    env ASAN_OPTIONS=detect_leaks=0 ./build/Vtop -d "${NEMU_REF_SO}" -b "${bin}" > "${log}" 2>&1 || status=$?
  if [[ "${status}" -eq 124 ]]; then
    echo "TIMEOUT after ${timeout_sec}s: ${category}/${name}" >&2
    return 1
  fi
  if [[ "${status}" -ne 0 ]]; then
    echo "Vtop exited with status ${status}: ${category}/${name}" >&2
    return 1
  fi

  grep -q "HIT GOOD TRAP" "${log}"
  if grep -Eiq "fatal|mismatch|ABORT|bad trap|BAD TRAP|AddressSanitizer|assert|non-convergence" "${log}"; then
    echo "failure marker found in ${log}" >&2
    return 1
  fi
}

run_group() {
  local category="$1"
  local dir="$2"
  local expected="$3"
  local count=0

  while IFS= read -r bin; do
    local base
    base="$(basename "${bin}" -riscv64-npc.bin)"
    run_image "${category}" "${base}" "${bin}"
    count=$((count + 1))
  done < <(find "${dir}" -maxdepth 1 -type f -name '*-riscv64-npc.bin' | sort)

  if [[ "${count}" -ne "${expected}" ]]; then
    echo "${category}: expected ${expected}, ran ${count}" >&2
    return 1
  fi

  echo "${category}: PASS ${count}/${expected}"
}

build_timer128() {
  riscv64-linux-gnu-gcc -nostdlib -nostartfiles -static -fno-pic -fno-pie \
    -no-pie -march=rv64im -mabi=lp64 \
    -Wl,--build-id=none -Wl,--no-relax \
    -T tests/custom/timer128_interrupt_mret.ld \
    -o "${ARTIFACT_DIR}/timer128_interrupt_mret.elf" \
    tests/custom/timer128_interrupt_mret.S
  riscv64-linux-gnu-objcopy -O binary \
    "${ARTIFACT_DIR}/timer128_interrupt_mret.elf" \
    "${ARTIFACT_DIR}/timer128_interrupt_mret.bin"
}

run_rtc_window() {
  local bin="${AM_KERNELS_DIR}/tests/am-tests/build/amtest-riscv64-npc.bin"
  local log="${LOG_DIR}/am-rtc.log"
  timeout 15s env ASAN_OPTIONS=detect_leaks=0 ./build/Vtop -d "${NEMU_REF_SO}" -b "${bin}" > "${log}" 2>&1 || true
  grep -q "GMT" "${log}"
  grep -Eq "\([1-9][0-9]* seconds\)" "${log}"
  if grep -Eiq "fatal|mismatch|ABORT|bad trap|BAD TRAP|AddressSanitizer|assert|non-convergence" "${log}"; then
    echo "failure marker found in ${log}" >&2
    return 1
  fi
  echo "AM RTC: PASS"
}

make build -j1

run_group "cpu" "${AM_KERNELS_DIR}/tests/cpu-tests/build" 33
run_group "klib" "${AM_KERNELS_DIR}/tests/klib-tests/build" 33
run_group "klib-unit" "${AM_KERNELS_DIR}/tests/klib-unit-tests-zrv/build" 8

run_image "bench" "microbench" "${AM_KERNELS_DIR}/benchmarks/microbench/build/microbench-riscv64-npc.bin" "${MICROBENCH_TIMEOUT_SEC}"
grep -q "MicroBench PASS" "${LOG_DIR}/bench-microbench.log"
echo "MicroBench: PASS"

run_image "am" "hello" "${AM_KERNELS_DIR}/kernels/hello/build/hello-riscv64-npc.bin"
grep -q "Hello, AbstractMachine!" "${LOG_DIR}/am-hello.log"
echo "AM hello: PASS"

run_rtc_window

build_timer128
run_image "custom" "timer128_interrupt_mret" "${ARTIFACT_DIR}/timer128_interrupt_mret.bin"
echo "timer128 interrupt and mret: PASS"

intr_directed_result="$(scripts/run_intr_directed.sh)"
echo "${intr_directed_result}"

cat > "${LOG_DIR}/summary.txt" <<SUMMARY
CPU tests: 33/33 PASS
klib tests: 33/33 PASS
dedicated klib unit tests: 8/8 PASS
MicroBench: PASS
AM hello: PASS
AM RTC: PASS
timer128 interrupt and mret: PASS
${intr_directed_result}
DiffTest fatal markers: 0
bad trap: 0
abort: 0
assertion failure: 0
non-convergence marker: 0
SUMMARY

cat "${LOG_DIR}/summary.txt"
