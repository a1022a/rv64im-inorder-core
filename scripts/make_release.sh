#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

OUT_DIR="${OUT_DIR:-out}"
RELEASE_ROOT="${OUT_DIR}/release"
ARTIFACT_DIR="${RELEASE_ROOT}/artifacts"
LOG_DIR="${OUT_DIR}/logs/release"

mkdir -p "${RELEASE_ROOT}" "${ARTIFACT_DIR}" "${LOG_DIR}"

version_file="${RELEASE_ROOT}/VERSION.txt"
manifest_file="${RELEASE_ROOT}/MANIFEST.txt"
sha_file="${RELEASE_ROOT}/SHA256SUMS.txt"
artifact_sha_file="${RELEASE_ROOT}/ARTIFACT_SHA256SUMS.txt"

head_sha="$(git rev-parse HEAD)"
head_short="$(git rev-parse --short=12 HEAD)"
branch="$(git rev-parse --abbrev-ref HEAD)"
archive_name="rv64im-inorder-core-${head_short}.tar.gz"
archive_path="${ARTIFACT_DIR}/${archive_name}"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "release requires a clean Git worktree" >&2
  exit 1
fi

{
  printf 'project=rv64im-inorder-core\n'
  printf 'branch=%s\n' "${branch}"
  printf 'commit=%s\n' "${head_sha}"
  printf 'simulation_top=rv64im_core_sim_top\n'
  printf 'synthesis_top=rv64im_core_top\n'
  printf 'verilator_prefix=Vtop\n'
  printf 'ram_synthesis_strategy=TBD\n'
} > "${version_file}"

git ls-files \
  | LC_ALL=C sort \
  | awk '
      function allowed(path) {
        if (path == "README.md") return 1
        if (path == ".gitignore") return 1
        if (path == "Makefile") return 1
        if (path == "config/default.mk") return 1
        if (path == "config/local.mk.example") return 1
        if (path == "models/README.md") return 1
        if (path == "docs/architecture.md") return 1
        if (path == "docs/build.md") return 1
        if (path == "docs/verification.md") return 1
        if (path == "docs/known_issues.md") return 1
        if (path == "docs/origin_provenance.md") return 1
        if (path == "docs/synthesis_handoff.md") return 1
        if (path ~ /^rtl\//) return 1
        if (path ~ /^sim\//) return 1
        if (path ~ /^scripts\//) return 1
        if (path ~ /^tests\//) return 1
        if (path ~ /^synth\//) return 1
        return 0
      }
      function excluded(path) {
        if (path == "AGENTS.md") return 1
        if (path == "EXECUTION_PLAN.md") return 1
        if (path == "zrv.f") return 1
        if (path == "config/local.mk") return 1
        if (path == "docs/engineering_inventory.md") return 1
        if (path ~ /^docs\/history\//) return 1
        if (path ~ /^build\//) return 1
        if (path ~ /^out\//) return 1
        if (path ~ /^obj_dir\//) return 1
        if (path ~ /^work\//) return 1
        if (path ~ /\.bak$/) return 1
        if (path ~ /\.before_split/) return 1
        return 0
      }
      allowed($0) && !excluded($0) { print }
    ' > "${manifest_file}"

{
  printf '# Release manifest\n'
  printf '# Generated from %s\n' "${head_sha}"
  printf '# RAM synthesis strategy: TBD\n'
  cat "${manifest_file}"
} > "${RELEASE_ROOT}/RELEASE_NOTES.txt"

while IFS= read -r path; do
  sha256sum "${path}"
done < "${manifest_file}" > "${sha_file}"

tar --sort=name \
  --mtime='UTC 1970-01-01' \
  --owner=0 --group=0 --numeric-owner \
  --transform "s#^#rv64im-inorder-core-${head_short}/#" \
  -czf "${archive_path}" \
  -T "${manifest_file}"

sha256sum "${archive_path}" "${version_file}" "${manifest_file}" \
  "${sha_file}" "${RELEASE_ROOT}/RELEASE_NOTES.txt" \
  > "${artifact_sha_file}"

cat > "${LOG_DIR}/summary.txt" <<SUMMARY
release artifact: ${archive_path}
version file: ${version_file}
manifest: ${manifest_file}
source sha256: ${sha_file}
artifact sha256: ${artifact_sha_file}
RAM synthesis strategy: TBD
formal synthesis: NOT RUN
STA: NOT RUN
LEC: NOT RUN
PPA evaluation: NOT RUN
SUMMARY

cat "${LOG_DIR}/summary.txt"
