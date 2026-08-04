# Architecture Summary

This repository contains an in-order RV64IM core engineering workspace.

Current active top-level identity:

- Simulation top: `rv64im_core_sim_top`
- Synthesis top candidate: `rv64im_core_top`
- Verilator class and executable prefix: `Vtop`

The simulation top is intentionally separate from the synthesis top. It imports
DPI helpers and exposes writeback, interrupt, and device-event signals consumed
by the C++ simulator and DiffTest harness. The synthesis top candidate excludes
the DPI boundary but still depends on the current RAM implementation.

The active RTL naming cleanup is complete for planned project-owned `zrv` and
`ZRV` identifiers in active sources. Historical files, external environment
names, and backup/provenance material keep their original names.

RAM synthesis strategy remains `TBD`. No SRAM macro, black-box replacement, or
behavioral-RAM synthesis policy has been selected.
