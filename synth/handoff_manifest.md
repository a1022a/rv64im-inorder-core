# Synthesis Handoff Manifest

Current synthesis boundary:

- Top candidate: `rv64im_core_top`
- RTL scope: `rtl/filelists/synth.f`
- Simulation-only top excluded from synthesis scope: `rv64im_core_sim_top`

Not run in this phase:

- Formal synthesis
- Static timing analysis
- Logic equivalence checking
- PPA evaluation

Unresolved:

- RAM synthesis strategy for `S011HD1P_X32Y2D128_BW.sv` remains `TBD`.
- No memory macro, SRAM compiler output, black-box model, or behavioral-RAM
  synthesis policy is approved by this handoff.
