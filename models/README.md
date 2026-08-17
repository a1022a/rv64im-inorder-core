# Performance models

These models preserve the measurement path that selected the final RTL change.
They are analysis tools, not architectural simulators and not timing predictors.

- `attribution/`: exclusive ROI and retirement attribution monitor
- `branch/`: conditional-predictor replay, error morphology, capacity sweep
- `cache/`: C0/C1 counter analysis and C2 exact tree-PLRU replay
- `loaduse/`: dependency episodes and counterfactual cycle removal
- `loaduse_p1/`: GOL harness used for measured P1 comparison

Raw traces, model output directories, and binaries are generated locally and
ignored. Qualified compact results live in `results/public/`.
