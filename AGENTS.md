# Repository guidance

This is the public A2 performance-and-timing-closure branch. Keep generated
builds, traces, logs, EDA sessions, mapped netlists, technology databases,
license configuration, machine-local paths, and credentials out of Git.

Before publishing a change, run the relevant functional and directed tests,
`git diff --check`, and the sanitization scans documented in
`docs/verification.md`. Synthesizable RTL changes must identify their source or
new qualification evidence. Do not weaken attribution, copyright, provenance,
or claim boundaries. The active public ASIC flow is `eda/`; `synth/` is a
legacy pointer only.
