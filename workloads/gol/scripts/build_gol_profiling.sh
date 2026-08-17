#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
profile_root="${GOL_WORKLOAD_DIR:-${repo_root}/out/gol}"
build_root="${profile_root}/build"

mkdir -p "${build_root}"
cd "${repo_root}"
exec verilator --cc --exe --build --top-module rv64im_core_top --prefix VgolProfile \
  --Mdir "${build_root}/obj_dir" \
  -I"${repo_root}/rtl/vsrc" \
  -f "${repo_root}/rtl/filelists/synth.f" \
  "${repo_root}/workloads/gol/scripts/gol_profiling_verilator_harness.cpp"
