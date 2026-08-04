#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

load_config() {
  # shellcheck disable=SC1091
  source scripts/lib/config.sh
}

run_dummy() {
  local log_path="$1"

  if [[ -z "${DEFAULT_DUMMY_IMG:-}" ]]; then
    echo "DEFAULT_DUMMY_IMG is not configured" >&2
    return 1
  fi
  if [[ ! -f "${DEFAULT_DUMMY_IMG}" ]]; then
    echo "DEFAULT_DUMMY_IMG not found: ${DEFAULT_DUMMY_IMG}" >&2
    return 1
  fi

  mkdir -p "$(dirname "${log_path}")"
  ASAN_OPTIONS="${ASAN_OPTIONS:-detect_leaks=0}" \
    make run-img IMG="${DEFAULT_DUMMY_IMG}" > "${log_path}" 2>&1
  grep -q "HIT GOOD TRAP" "${log_path}"
  if grep -Ei "fatal|mismatch|ABORT|bad trap" "${log_path}" >/dev/null; then
    echo "fatal marker found in ${log_path}" >&2
    return 1
  fi
}

run_test() {
  local test_name="$1"
  case "${test_name}" in
    dummy)
      run_dummy "out/logs/run/dummy.log"
      ;;
    ""|\#*)
      ;;
    *)
      echo "unknown smoke/regress test: ${test_name}" >&2
      return 1
      ;;
  esac
}

run_manifest() {
  local manifest="$1"
  if [[ ! -f "${manifest}" ]]; then
    echo "manifest not found: ${manifest}" >&2
    return 1
  fi

  local count=0
  while IFS= read -r test_name; do
    [[ -z "${test_name}" || "${test_name}" == \#* ]] && continue
    run_test "${test_name}"
    count=$((count + 1))
  done < "${manifest}"
  echo "PASS ${count}/${count}"
}

main() {
  load_config

  if [[ "${1:-}" == "--manifest" ]]; then
    run_manifest "${2:?manifest path required}"
  else
    run_test "${1:-dummy}"
  fi
}

main "$@"
