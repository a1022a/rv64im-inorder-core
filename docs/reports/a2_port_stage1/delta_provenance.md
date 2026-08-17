# A2 Delta Provenance

| File | Classification | Result |
| --- | --- | --- |
| `rtl/filelists/lint.f` | A2_REQUIRED | Add wrapper; remove old SRAM model. |
| `rtl/filelists/sim.f` | A2_REQUIRED | Add wrapper; remove old SRAM model. |
| `rtl/filelists/synth.f` | A2_REQUIRED | Add wrapper; remove old SRAM model. |
| `rtl/vsrc/cache/rv64im_core_ram.sv` | A2_REQUIRED | Preserve four banks through 64x64 wrappers. |
| `rtl/vsrc/cache/rv64im_core_sram64x64.sv` | A2_REQUIRED | New generic/ASIC abstraction. |
| `rtl/vsrc/rv64im_core_top.sv` | A2_REQUIRED | Parameterize both cache sizes; I-cache 8192. |
| `rtl/vsrc/rv64im_core_sim_top.sv` | PREEXISTING_NON_A2_DELTA | Prior simulation declaration/logic fix; excluded. |
| `rtl/vsrc/units/rv64im_core_add4to2.sv` | PREEXISTING_NON_A2_DELTA | Prior DC genvar/bit-0 fix; unrelated; excluded. |

No delta was classified `ALREADY_IN_DEV` or `UNKNOWN`.
