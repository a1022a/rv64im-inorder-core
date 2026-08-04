# Origin And Provenance

Functional baseline:

- Commit: `59bcac3`
- Tag: `v0.1.0-functional-baseline`

Baseline and import evidence is retained under `docs/history/`. Do not delete
or rewrite historical source, attribution, license, baseline validation, or
import records during engineering cleanup.

Preserved legacy contexts:

- `docs/history/filelists/legacy_zrv.f` remains a legacy audit artifact, is not
  used by the stable build, and is excluded from publication release artifacts.
- `rtl/vsrc/exu/zrv_booth_mul.sv.before_split_var_20260802` is preserved as a
  backup/provenance file and excluded from active filelists.
- External environment names such as `ysyx-workbench`, NEMU, Abstract Machine,
  am-kernels, and ysyxSoC are not project-owned RTL identifiers and must not be
  blindly renamed.
