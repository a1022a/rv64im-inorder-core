# RV64IM A2 RFIC publication bundle

This is a sanitized ASIC methodology and evidence package for the RV64IM A2 CPU. It covers the baseline pilot and frequency sweep, critical-path migration, fast/min internal hold, load-use timing feasibility, the P1 500 MHz near miss, the P2 tool-compatibility failure, and final P2R1 500 MHz closure.

`eda/` contains sanitized copies of scripts actually used in the experiments plus a generic characterization SDC. `docs/asic/` explains methodology and engineering decisions. `results/public/asic/` contains compact machine-readable results. Proprietary technology/IP views, license configuration, mapped netlists, tool sessions, DDC, and raw logs are intentionally excluded.

To adapt the flow, provide project-local values for `PROJECT_WORKSPACE`, `STDCELL_MAX_DB`, `SRAM_MAX_DB`, `STDCELL_MIN_DB`, `SRAM_MIN_DB`, library-name variables, and `SRAM_MACRO_REF`. A compatible synthesis/STA installation and authorized technology environment are still required; this bundle does not make the flow portable outside such an environment.

The reported closure is pre-layout synthesized ASIC frontend characterization, not post-route, signoff, product, or silicon Fmax. Power is not closed.
