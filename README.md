# RV64IM In-Order Core — A2 Performance and Timing Closure

This repository publishes a single-issue, in-order RV64IM_Zicsr core and the
engineering evidence behind its A2 performance optimization and 500 MHz
pre-layout timing closure. The accepted RTL combines an SRAM-backed cache
organization, a one-cycle load-hit-use bypass, and a cycle-equivalent divider
result cleanup (DRC1). Just as importantly, the repository retains rejected
branch- and cache-capacity experiments so the final design choice is auditable.

## What changed and why

Exclusive cycle attribution showed that the main GOL256 workload spent about
21.55% of its ROI in load-use dependencies. Branch predictor capacity sweeps
produced essentially no improvement, and exact four-way tree-PLRU replay found
no GOL256 D-cache miss reduction from 4 through 32 KiB. Those two candidates
were stopped. The qualified load-hit-use bypass reduced GOL256 from 2,394,963
to 1,880,884 cycles (1.273317759x) without changing miss or flush behavior.

Fresh synthesis of that P1 design at 500 MHz then missed setup by 1.319 ps.
Path analysis showed that the bypass was not the failing path; the dominant
cone was divider-result forwarding into ID. DRC1 stores the signed quotient at
divider completion and preserves bit- and cycle-level behavior. An initial P2
revision exposed a DC PRESTO VER-956 declaration-order incompatibility. P2R1
fixed declaration order, passed the functional gates, and closed fresh setup
and hold analysis at 500 MHz. The former DIV-to-ID cone left the top 20 and the
critical path migrated to the CSR cycle counter.

## Architecture

- RV64IM base ISA plus implemented Zicsr behavior
- Single-issue, in-order pipeline
- SRAM-based instruction and data caches; four-way D-cache tree-PLRU
- Verilator simulation top: `rv64im_core_sim_top`
- Synthesis top: `rv64im_core_top`
- One-cycle load-hit-use bypass qualified by an accepted request, valid D-cache
  tag hit, formatted LSU response, and matching dependent EX operands
- Iterative divider with DRC1 completion-time signed quotient storage

See [architecture](docs/architecture.md) and [known issues](docs/known_issues.md)
for the exact supported boundary.

## Repository map

- `rtl/`: accepted synthesizable RTL and filelists
- `sim/`: simulator, DiffTest integration, and performance observers
- `tests/custom/`: directed cache, load-use, interrupt, and divider tests
- `workloads/gol/`: portable GOL image generator, harness, and checksum oracles
- `models/`: attribution, branch replay, cache replay, and load-use analysis
- `scripts/`: functional, directed, and performance runners
- `eda/`: sanitized DC/PT methodology, constraints, and analysis scripts
- `docs/experiments/`: chronological experiment records, including STOP decisions
- `docs/final/`: final narrative, DSE matrix, result summary, and artifact index
- `results/public/`: compact machine-readable qualified results
- `synth/`: legacy compatibility notes; the active public flow is `eda/`

## Quick start

Install Verilator, LLVM 12 development tools, SDL2, the RISC-V GNU toolchain,
and provide an RV64 NEMU reference plus AM kernels through a private
`config/local.mk` (copy `config/local.mk.example`). Then run:

```sh
make doctor
make build
make run TEST=dummy
make smoke
make regress
scripts/run_icache_64set_directed.sh
scripts/run_loaduse_p1_directed.sh
P1_REFERENCE_DIR=/path/to/p1 scripts/run_divider_drc1_directed.sh
GOL_WORKLOAD_DIR=/path/to/generated/gol scripts/run_loaduse_p1_performance.sh
```

Generated binaries, traces, waveforms, logs, EDA sessions, mapped netlists,
and machine-local configuration are intentionally excluded from Git.

## Workload and modeling methodology

The GOL workload is deterministically generated for multiple grid sizes and
checked against published checksums. Performance measurements use explicit ROI
boundaries and retired-work attribution. Cache studies collect C0/C1 hardware
observations and replay accepted D-cache accesses, including PRE_ROI warmup,
with RTL-equivalent four-way tree-PLRU. Branch studies replay conditional
prediction and sweep capacity. Load-use analysis attributes exclusive episodes
and evaluates perfect-dependency and one-cycle-hit counterfactuals before RTL is
changed. Raw traces are reproducible outputs, not publication inputs.

## Design-space exploration

| Candidate | Evidence | Decision |
|---|---|---|
| Branch predictor 512/1024/2048 entries | FIB errors 602/603/603; Bubble 104/104/104 | `STOP_BRANCH_DSE` |
| D-cache 4/8/16/32 KiB | GOL256 misses 4080/4080/4080/4080 | `STOP_CACHE_DSE`; no RTL change |
| One-cycle load-hit-use bypass | Predicted and measured about 1.2733x on GOL256 | Accepted as P1 |
| DIV forwarding topology cleanup | P1 setup failure rooted in DIV-to-ID cone | DRC1 accepted |
| Extra DIV dependency bubble | Workloads have dynamic DIV count 0, but adds a nominal cycle | Fallback only |

The complete comparison and rejected-route rationale are in
[design_space_exploration.md](docs/final/design_space_exploration.md).

## Verification and quantitative result

The final functional matrix covers 33 CPU tests, 33 CPU tests with klib, eight
klib unit tests, MicroBench, AM hello/RTC, interrupt handling, the 64-set
I-cache test, load-use directed tests, and 854 divider cases. Divider coverage
includes all RV64 and W-form DIV/REM variants, zero division, signed overflow,
random, back-to-back, stall-hold, and dependent-consumer cases. Selected corner
cases use standalone expected values, P1/P2 bit-and-cycle equivalence, and
W-form self-checking because the patched local NEMU oracle is not reliable for
every such case.

| Metric | Original | Final |
|---|---:|---:|
| GOL256 ROI cycles | 2,394,963 | 1,880,884 |
| Required frequency at 180 GPS | 431.093340 MHz | 338.559120 MHz |
| 500 MHz PT setup WNS | — | +0.000097 ns |
| 500 MHz hold WNS | — | +0.037408 ns |
| Total area | 264,938.885248 | 272,919.319248 (+3.012179%) |

The load-use direct probe is +0.129794 ns and is not in the top 20 paths.
Power is not closed.

## ASIC methodology and limits

The public EDA material is a sanitized, reproducible methodology shell for
fresh DC compilation and PT setup/hold analysis. It contains no PDK database,
license configuration, mapped netlist, session, or proprietary binary. The
supported claim is narrowly: **500 MHz pre-layout synthesized ASIC front-end
setup/hold closure**. It is not post-route closure, signoff Fmax, silicon or
product Fmax, or full PPA. There is no place-and-route, CTS, extracted
parasitics, post-route STA, or power closure.

## Reproduction and provenance

Start with [build.md](docs/build.md), then follow
[verification.md](docs/verification.md), the per-experiment READMEs, and the
sanitized `eda/README.md`. The accepted synthesizable RTL is copied exactly
from frozen commit `217f2640b170f12f276e711a9aa08ac50cd7c946`; provenance for
every stage is recorded in [origin_provenance.md](docs/origin_provenance.md).
The [artifact index](docs/final/artifact_index.md) maps scripts, documents, and
result tables to their experiment stages and frozen commits.
