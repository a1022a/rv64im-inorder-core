#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

OUT_DIR="${OUT_DIR:-out}"
BUILD_DIR="${OUT_DIR}/intr_directed/build"
LOG_DIR="${OUT_DIR}/logs/intr_directed"
LOG_FILE="${LOG_DIR}/intr_directed.log"

mkdir -p "${BUILD_DIR}" "${LOG_DIR}"

verilator --cc --exe --build \
  "${ROOT_DIR}/tests/custom/intr_directed_top.sv" \
  "${ROOT_DIR}/tests/custom/intr_directed_tb.cpp" \
  "${ROOT_DIR}/rtl/vsrc/units/rv64im_core_reg.sv" \
  "${ROOT_DIR}/rtl/vsrc/exu/rv64im_core_csr_reg.sv" \
  "${ROOT_DIR}/rtl/vsrc/exu/rv64im_core_intr_ctrl.sv" \
  "${ROOT_DIR}/rtl/vsrc/bus/rv64im_core_clint.sv" \
  -I./rtl/vsrc \
  -top intr_directed_top \
  --Mdir "${BUILD_DIR}" \
  > "${LOG_FILE}" 2>&1

"${BUILD_DIR}/Vintr_directed_top" >> "${LOG_FILE}" 2>&1
echo "directed machine interrupt tests: PASS"
