#!/bin/bash
set -u

if [ "$#" -ne 4 ]; then
    echo "usage: $0 PT_RUN_DIR DC_POINT_RUN_DIR EXPECTED_PERIOD_NS EXPECTED_TIMING_STATUS" >&2
    exit 64
fi

export PT_RUN_DIR="$1"
export DC_POINT_RUN_DIR="$2"
export EXPECTED_PERIOD_NS="$3"
export EXPECTED_TIMING_STATUS="$4"
PT_BIN=${PT_BIN:?set PT_BIN to the authorized PrimeTime executable}

mkdir -p "$PT_RUN_DIR/scripts" "$PT_RUN_DIR/logs" "$PT_RUN_DIR/reports" "$PT_RUN_DIR/metadata"
test -r "$PT_RUN_DIR/scripts/pt_boundary_max.tcl" || exit 66

{
    echo "PT_RUN_DIR=$PT_RUN_DIR"
    echo "DC_POINT_RUN_DIR=$DC_POINT_RUN_DIR"
    echo "EXPECTED_PERIOD_NS=$EXPECTED_PERIOD_NS"
    echo "EXPECTED_TIMING_STATUS=$EXPECTED_TIMING_STATUS"
    date -u '+RUN_START_UTC=%Y-%m-%dT%H:%M:%SZ'
} > "$PT_RUN_DIR/metadata/run_config.env"
sha256sum "$DC_POINT_RUN_DIR/outputs/rv64im_core_top_mapped.v" "$DC_POINT_RUN_DIR/constraints/characterization_effective.sdc" > "$PT_RUN_DIR/metadata/input_sha256.txt"
sha256sum "$PT_RUN_DIR/scripts/pt_boundary_max.tcl" "$PT_RUN_DIR/scripts/run_pt_boundary.sh" > "$PT_RUN_DIR/metadata/script_sha256.txt"
"$PT_BIN" -version > "$PT_RUN_DIR/metadata/pt_version.txt" 2>&1

cd "$PT_RUN_DIR"
set +e
"$PT_BIN" -f "$PT_RUN_DIR/scripts/pt_boundary_max.tcl" 2>&1 | tee "$PT_RUN_DIR/logs/pt_boundary_max.log"
pt_rc=${PIPESTATUS[0]}
set -e

if [ "$pt_rc" -eq 0 ] && grep -Fxq 'PT_FLOW_STATUS=PASS' "$PT_RUN_DIR/metadata/pt_boundary.env" && ! grep -Fxq 'PT_FLOW_STATUS=FAIL' "$PT_RUN_DIR/metadata/pt_boundary.env"; then
    printf 'PT_PROCESS_EXIT_CODE=%s\nPT_EXIT_CODE=0\n' "$pt_rc" > "$PT_RUN_DIR/metadata/pt_exit_code.env"
    date -u '+RUN_END_UTC=%Y-%m-%dT%H:%M:%SZ' >> "$PT_RUN_DIR/metadata/run_config.env"
    exit 0
fi

printf 'PT_PROCESS_EXIT_CODE=%s\nPT_EXIT_CODE=2\n' "$pt_rc" > "$PT_RUN_DIR/metadata/pt_exit_code.env"
date -u '+RUN_END_UTC=%Y-%m-%dT%H:%M:%SZ' >> "$PT_RUN_DIR/metadata/run_config.env"
exit 2
