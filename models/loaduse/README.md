# Load-use dependency model

`analyze_dependency_profile.py` consumes simulation-only per-episode JSON,
writes CSV, derives dependency morphology, and evaluates perfect-dependency,
perfect-load-use, and one-cycle load-hit-use counterfactuals. It removes only
measured exclusive cycles; it does not predict timing or itself prove bypass
implementability. Raw profiles are generated under ignored local output paths.

GOL256 attributes 516,128 dependency/load-use cycles, of which 514,080 are
load-hit episodes. The one-cycle counterfactual predicted 1,880,883 cycles; the
implemented P1 measured 1,880,884 cycles.
