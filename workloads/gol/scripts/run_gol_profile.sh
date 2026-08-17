#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: run_gol_profile.sh GRID EXPECTED_CHECKSUM TIMEOUT_SECONDS RUN_INDEX LOG" >&2
  exit 64
fi

grid="$1"
expected_checksum="$2"
timeout_seconds="$3"
run_index="$4"
log_path="$5"
: "${GOL_WORKLOAD_DIR:?set GOL_WORKLOAD_DIR to the generated GOL workload directory}"
profile_root="${GOL_WORKLOAD_DIR}"
binary="${profile_root}/build/obj_dir/VgolProfile"
image="${profile_root}/images/program_${grid}x${grid}.hex"

{
  /usr/bin/time -f 'HOST_WALLCLOCK_RUNTIME_SEC=%e' \
    timeout "${timeout_seconds}" "${binary}" "${image}" "${expected_checksum}"
  status=$?
  echo "RUN_EXIT_STATUS=${status}"
  echo "GRID=${grid}"
  echo "RUN_INDEX=${run_index}"
  exit "${status}"
} > "${log_path}" 2>&1
