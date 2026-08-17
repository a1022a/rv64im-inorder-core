# A2 Phase 4 Metric Validation

## Objective

Validate the Phase 3 simulation-only raw-observation interface within a
controlled directed region of interest (ROI). This is counter-interface
validation, not workload performance characterization, analytical CPI
modeling, or design-space exploration.

## Controlled ROI

The opt-in collector accepts `PERF_ROI_START_PC` and `PERF_ROI_END_PC` as
distinct hexadecimal PC marker values. They are matched only against an
existing `wb_sign` observation. The start marker resets all raw counters and
is excluded; sampling begins on following rising edges. The end marker is
excluded and disables subsequent sampling. JSON reports `pc_marker_roi`, the
two marker PCs, and `roi_valid` only when both are observed in order.

Without both variables, collection retains the Phase 3 `full_run` behavior.
This is a simulation-only C++ feature; no RTL, CSR, ISA instruction, cache,
or synthesis source is changed.

## Directed evidence

`scripts/run_perf_roi_retire.sh` builds `tests/custom/perf_roi_retire.S` and
derives marker and expected instruction PCs from its linked ELF symbols. The
test checks one `wb_sign` observation in program order for every non-marker
instruction in its controlled region and proves that the taken branch's
labelled wrong-path instruction is absent.

The automated runner derives start/end markers and all expected writeback PCs
from the linked ELF. It rejects an invalid ROI, a nonzero exit, a duplicated
or missing writeback PC, or any of the three labelled wrong-path instructions.
The directed region contains independent ALU, RAW forwarding, ordinary store
and load, load-use dependency, divide, correctly predicted/not-taken and
direction-error conditional branches, JAL, JALR, and CSR read. Marker and
termination instructions are excluded.

The final directed run produced the following validation vector. Expected
writeback observations are the symbol-derived sequence; the remaining values
are deterministic raw-observation checks, not workload bottleneck data.

| Measurement | Expected | Observed |
|---|---:|---:|
| ROI cycles | 67 | 67 |
| writeback observations | 25 | 25 |
| resolved branch/jump observations | 4 | 4 |
| branch direction errors | 1 | 1 |
| I-cache miss observations | 4 | 4 |
| I-cache wait cycles | 27 | 27 |
| D-cache miss observations | 1 | 1 |
| D-cache/memory wait cycles | 10 | 10 |
| dependency/load-use stall cycles | 11 | 11 |
| divider wait cycles | 2 | 2 |
| generic flush observations | 3 | 3 |
| branch-flush observations | 2 | 2 |

One dependency-stall sample was also observed. The raw indicators may overlap;
no CPI contribution is calculated from their sum.

## Retirement conclusion

The exact-PC sequence supports `wb_sign` as a validated writeback/DiffTest
step observation for this directed subset, including bubbles/stalls and
redirected wrong paths. Final classification: **PARTIAL_RETIREMENT_EVENT**.
It is not yet an architectural retirement signal. Ecall, ebreak, mret,
synchronous/asynchronous interrupt, device-access, termination, and
arbitrary-workload cases remain unproven; retired instructions, IPC, CPI, and
architectural load/store counts remain unavailable. The existing timer128
interrupt/mret regression remains functional coverage but has no controlled
ROI and is not used for retirement-count validation.

## Metric status

| Raw metric | Directed result | Phase 4 status |
|---|---:|---|
| ROI cycles | 67 | VALIDATED PC-marker scope |
| `wb_sign` writeback observations | 25 expected / 25 observed | VALIDATED subset only |
| branch-resolved observation | 4 | VALIDATED for conditional, JAL, JALR mix |
| branch direction error | 1 | VALIDATED sampled condition error |
| JALR target error | 41 for one JALR | PROVISIONAL: level is not an event pulse |
| I-cache miss / wait | 4 / 27 | VALIDATED raw speculative-capable observation |
| D-cache miss / memory wait | 1 / 10 | VALIDATED raw request/stall observation |
| dependency stall | 11 | VALIDATED load-use presence; renamed from misleading flush name |
| divider wait | 2 | VALIDATED sampled pipeline block |
| generic / branch flush | 3 / 2 | VALIDATED raw sampled levels |

`perf_flush_dependency` was renamed in the JSON schema to
`dependency_stall_cycles`: it originates from `idu_pipe_stall` and is not a
pipeline flush. `jalr_target_error` remains a raw sampled level because the
directed JALR holds it for 41 samples; it cannot be aggregated into a
mispredict event count. Branch recovery and generic flush remain separate.

## Determinism and limits

Two identical runs of the directed runner produce byte-identical JSON output;
the recorded SHA-256 is
`a48524b617a93e03ca68bb1bfab365e6423488da2f0b58b73035b92ff220d680`. Full regression validates
that collection stays disabled by default. I-cache events may include
wrong-path fetches. D-cache request counts, and all decoded load/store counts,
must not be called architectural until retirement is proven.

## Regression gate and build reuse

The recorded `out/logs/regress/regress.log` and
`out/phase4_validation/regress.status` show a zero-exit full regression:

| Gate | Result |
|---|---|
| CPU tests | PASS 33/33 |
| CPU KLIB tests | PASS 33/33 |
| KLIB unit tests | PASS 8/8 |
| MicroBench | PASS |
| AM hello / RTC | PASS / PASS |
| timer interrupt/mret | PASS |
| directed machine interrupts | PASS |
| DiffTest fatal, bad trap, abort, assertion, non-convergence markers | 0, 0, 0, 0, 0 |

The archive SHA-256 before and after regression is unchanged:
`cfec76c99d964d2fcbbe729b6224d6e036501657f3f01bdcf3c9cb15a84487c9`
(`ARCHIVE_SHA_DIFF_STATUS=0`). This confirms the separately committed build
fix reuses `build/Vtop` during regression.

## Phase 4 status

Phase 4 is complete for ROI-scoped raw-observation validation. Validated
metrics are ROI cycles, the directed `wb_sign` observation subset,
branch-resolved and branch-direction-error observations, accepted cache-miss
observations, wait/stall occupancy, divider-wait occupancy, and sampled flush
observations. `jalr_target_error` is provisional because it is held level
data, not an event pulse. Architectural retired-instruction count, IPC, CPI,
retired load/store counts, and retirement-normalized MPKI remain **TBD**.
Retirement classification remains **PARTIAL_RETIREMENT_EVENT** and is deferred
to the separate retirement-closure step.
