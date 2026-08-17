# Experiment record

The directories are chronological and retain accepted, rejected, and failed
routes:

1. `00_baseline`: functional closure, ROI contract, attribution calibration
2. `01_branch_dse`: observable recovery, rejected capacity scaling
3. `02_cache_dse`: C0/C1 counters and C2 exact replay, rejected capacity change
4. `03_loaduse_dse`: exact dependency attribution and counterfactual model
5. `04_loaduse_p1`: accepted one-cycle load-hit-use bypass and measurement
6. `05_div_timing`: timing root cause, alternatives, DRC1, P2 failure, P2R1 closure

Each README is the public summary. `source_notes/` retains detailed qualified
notes where useful; machine-local paths have been removed.
