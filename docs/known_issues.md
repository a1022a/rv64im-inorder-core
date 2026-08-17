# Known issues and claim boundaries

- `mtvec` Vectored mode is not implemented, and the integration top ties the
  external interrupt input low. This is not a claim of full privileged-ISA
  compliance.
- Ordinary DiffTest inherits the configured NEMU reference's known `mie`
  comparison limitation.
- The patched NEMU reference is not a reliable oracle for every divider
  divide-by-zero, signed-overflow, or signed W-form corner; independent checks
  cover those selected cases.
- The 500 MHz result has only +0.000097 ns setup WNS. It is a qualified fresh
  pre-layout synthesized front-end result, not post-route or silicon margin.
- Power is not closed. No P&R, CTS, extracted parasitics, post-route STA, or
  signoff/full-PPA claim is included.
- Public EDA scripts require a licensed compatible environment and separately
  supplied technology collateral. No license or PDK database is published.
- Raw traces and workload images are intentionally generated rather than stored
  in Git; compact qualified results and checksum oracles are published.
