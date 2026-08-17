#!/bin/bash
set -u

RUN_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$RUN_DIR/metadata/point_config.env"
export SWEEP_POINT_RUN_DIR=$RUN_DIR
export CHAR_CLK_PERIOD_NS=$PERIOD_NS
DC_BIN=${DC_BIN:?set DC_BIN to the authorized Design Compiler executable}

"$DC_BIN" -version > "$RUN_DIR/metadata/dc_version.txt" 2>&1

set +e
"$DC_BIN" -no_gui -f "$RUN_DIR/scripts/dc_sweep_gate.tcl" 2>&1 | tee "$RUN_DIR/logs/dc_constraint_gate.log"
gate_process_rc=${PIPESTATUS[0]}
set -e
if [ "$gate_process_rc" -ne 0 ] || ! grep -Fxq 'DC_CONSTRAINT_VALIDATION=PASS' "$RUN_DIR/metadata/dc_constraint_gate.env" || grep -Fxq 'DC_CONSTRAINT_VALIDATION=FAIL' "$RUN_DIR/metadata/dc_constraint_gate.env"; then
    printf 'DC_GATE_PROCESS_EXIT_CODE=%s\nDC_EXIT_CODE=2\nFLOW_STATUS=FAIL\nFAILURE_PHASE=DC_CONSTRAINT_VALIDATION\n' "$gate_process_rc" > "$RUN_DIR/metadata/dc_exit_code.env"
    exit 2
fi

set +e
"$DC_BIN" -no_gui -f "$RUN_DIR/scripts/dc_sweep_compile.tcl" 2>&1 | tee "$RUN_DIR/logs/dc_compile_ultra.log"
compile_process_rc=${PIPESTATUS[0]}
set -e
if [ "$compile_process_rc" -eq 0 ] && grep -Fxq 'FLOW_STATUS=PASS' "$RUN_DIR/metadata/dc_point.env" && ! grep -Fxq 'FLOW_STATUS=FAIL' "$RUN_DIR/metadata/dc_point.env"; then
    printf 'DC_PROCESS_EXIT_CODE=%s\nDC_EXIT_CODE=0\nFLOW_STATUS=PASS\n' "$compile_process_rc" > "$RUN_DIR/metadata/dc_exit_code.env"
    sha256sum "$RUN_DIR/outputs/rv64im_core_top_mapped.v" "$RUN_DIR/outputs/rv64im_core_top_mapped.ddc" "$RUN_DIR/constraints/characterization_effective.sdc" > "$RUN_DIR/metadata/mapped_handoff_sha256.txt"
    exit 0
fi

printf 'DC_PROCESS_EXIT_CODE=%s\nDC_EXIT_CODE=2\nFLOW_STATUS=FAIL\nFAILURE_PHASE=DC_COMPILE_ULTRA_OR_POSTCHECK\n' "$compile_process_rc" > "$RUN_DIR/metadata/dc_exit_code.env"
exit 2
