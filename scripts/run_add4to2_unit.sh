#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out/add4to2_unit"
LOG_DIR="${ROOT_DIR}/out/logs/add4to2_unit"
SIM_BIN="${OUT_DIR}/add4to2_unit.vvp"
LOG_FILE="${LOG_DIR}/add4to2_unit.log"

mkdir -p "${OUT_DIR}" "${LOG_DIR}"

iverilog -g2012 -s add4to2_unit -o "${SIM_BIN}" \
  "${ROOT_DIR}/tests/custom/add4to2_unit.sv" \
  "${ROOT_DIR}/rtl/vsrc/units/rv64im_core_add4to2.sv" \
  "${ROOT_DIR}/rtl/vsrc/units/rv64im_core_add_full.sv"

vvp "${SIM_BIN}" | tee "${LOG_FILE}"
grep -qx 'ADD4TO2_EXHAUSTIVE_4BIT_VECTORS=65536' "${LOG_FILE}"
grep -qx 'ADD4TO2_DIRECTED_8BIT_VECTORS=7' "${LOG_FILE}"
grep -qx 'ADD4TO2_RANDOM_8BIT_VECTORS=1024' "${LOG_FILE}"
grep -qx 'ADD4TO2_STANDALONE_TEST=PASS' "${LOG_FILE}"

echo 'ADD4TO2_UNIT=PASS'
