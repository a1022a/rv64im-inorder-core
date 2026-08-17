#!/bin/bash
set -u

if [ "$#" -ne 5 ]; then
    echo "usage: $0 HOLD_RUN_DIR IMPLEMENTATION_NETLIST FAST_MIN_STDCELL_DB FAST_MIN_SRAM_DB SOURCE_SDC" >&2
    exit 64
fi

export HOLD_RUN_DIR="$1"
export IMPLEMENTATION_NETLIST="$2"
export FAST_MIN_STDCELL_DB="$3"
export FAST_MIN_SRAM_DB="$4"
export SOURCE_SDC="$5"
PT_BIN=${PT_BIN:?set PT_BIN to the authorized PrimeTime executable}

mkdir -p "$HOLD_RUN_DIR/scripts" "$HOLD_RUN_DIR/logs" "$HOLD_RUN_DIR/reports" "$HOLD_RUN_DIR/metadata"
test -r "$HOLD_RUN_DIR/scripts/pt_internal_hold.tcl" || exit 66

{
    echo "HOLD_RUN_DIR=$HOLD_RUN_DIR"
    echo "IMPLEMENTATION_NETLIST=$IMPLEMENTATION_NETLIST"
    echo "FAST_MIN_STDCELL_DB=$FAST_MIN_STDCELL_DB"
    echo "FAST_MIN_SRAM_DB=$FAST_MIN_SRAM_DB"
    echo "SOURCE_SDC=$SOURCE_SDC"
    date -u '+RUN_START_UTC=%Y-%m-%dT%H:%M:%SZ'
} > "$HOLD_RUN_DIR/metadata/run_config.env"
sha256sum "$IMPLEMENTATION_NETLIST" "$FAST_MIN_STDCELL_DB" "$FAST_MIN_SRAM_DB" "$SOURCE_SDC" > "$HOLD_RUN_DIR/metadata/input_sha256.txt"
sha256sum "$HOLD_RUN_DIR/scripts/pt_internal_hold.tcl" "$HOLD_RUN_DIR/scripts/run_pt_internal_hold.sh" > "$HOLD_RUN_DIR/metadata/script_sha256.txt"
"$PT_BIN" -version > "$HOLD_RUN_DIR/metadata/pt_version.txt" 2>&1

cd "$HOLD_RUN_DIR"
set +e
"$PT_BIN" -f "$HOLD_RUN_DIR/scripts/pt_internal_hold.tcl" 2>&1 | tee "$HOLD_RUN_DIR/logs/pt_internal_hold.log"
pt_rc=${PIPESTATUS[0]}
set -e

if [ "$pt_rc" -eq 0 ] && grep -Fxq 'PT_INTERNAL_HOLD_RUN=PASS' "$HOLD_RUN_DIR/metadata/pt_internal_hold.env" && ! grep -Fxq 'PT_INTERNAL_HOLD_RUN=FAIL' "$HOLD_RUN_DIR/metadata/pt_internal_hold.env"; then
    printf 'PT_PROCESS_EXIT_CODE=%s\nPT_EXIT_CODE=0\n' "$pt_rc" > "$HOLD_RUN_DIR/metadata/pt_exit_code.env"
    date -u '+RUN_END_UTC=%Y-%m-%dT%H:%M:%SZ' >> "$HOLD_RUN_DIR/metadata/run_config.env"
    exit 0
fi

printf 'PT_PROCESS_EXIT_CODE=%s\nPT_EXIT_CODE=2\n' "$pt_rc" > "$HOLD_RUN_DIR/metadata/pt_exit_code.env"
date -u '+RUN_END_UTC=%Y-%m-%dT%H:%M:%SZ' >> "$HOLD_RUN_DIR/metadata/run_config.env"
exit 2
