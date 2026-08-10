# A2 Static Checks

- `git diff --check`: PASS.
- All three filelists include `rv64im_core_sram64x64.sv` and exclude the old `S011HD1P_X32Y2D128_BW.sv` model.
- No proprietary vendor file, Liberty, or DB path is included.
- Geometry/address audit: see `semantic_merge.md`.
