#!/usr/bin/env bash
set -euo pipefail

make_value() {
  local name="$1"
  make --no-print-directory -f - print-value <<MAKE_EOF
include config/default.mk
-include config/local.mk
print-value:
	@printf '%s\n' \$(${name})
MAKE_EOF
}

NEMU_REF_SO="$(make_value NEMU_REF_SO)"
AM_KERNELS_DIR="$(make_value AM_KERNELS_DIR)"
DEFAULT_DUMMY_IMG="$(make_value DEFAULT_DUMMY_IMG)"
REGRESS_TIMEOUT_SEC="$(make_value REGRESS_TIMEOUT_SEC)"
MICROBENCH_TIMEOUT_SEC="$(make_value MICROBENCH_TIMEOUT_SEC)"
