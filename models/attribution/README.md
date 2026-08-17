# Exclusive performance attribution

`perf_observer` and `run_perf_roi_retire.sh` implement the baseline ROI and
retirement accounting used before candidate-specific modeling. Attribution is
exclusive so overlapping observations are not double-counted. The included
assembly test qualifies ROI marker and retire behavior. See
`docs/experiments/00_baseline/README.md` for the measurement contract.
