# Artifact index

| GitHub path | Artifact | Stage / frozen source | Generated? | Reproducible? |
|---|---|---|---|---|
| `rtl/` | Final accepted synthesizable RTL | P2R1 `217f2640b170f12f276e711a9aa08ac50cd7c946` | No | Exact source copy |
| `sim/csrc/dependency_observer.*` | Dependency episode observer | Load-use modeling `a3386e568c42f46568170626f0e774441fd21d91` / P1 | No | Yes |
| `models/attribution/` | ROI/retirement attribution | Modeling `a82a98a01eb5cee84eb5497890f16366fb6814e2` | No | Yes |
| `models/branch/` | Replay, morphology, capacity sweep | Modeling `a82a98a01eb5cee84eb5497890f16366fb6814e2` | No | Yes from qualified trace input |
| `models/cache/` | C0/C1 analysis and C2 tree-PLRU replay | Cache `68988e93...` / `82172832...` | No | Yes from accepted access trace |
| `models/loaduse/` | Episode/counterfactual analysis | Load-use `a3386e568c42f46568170626f0e774441fd21d91` | No | Yes from observer JSON |
| `workloads/gol/` | Image generator, harness, checksum oracle | Workload qualification stage | Images/binaries yes; sources no | Yes |
| `scripts/run_loaduse_p1_*` | Directed/performance qualification | P1 `4858651e70bd41fb9cc789a4b09a3f0de624d46a` | Logs/builds yes | Yes with configured dependencies |
| `scripts/run_divider_drc1_directed.sh` and divider tests | 854-case DRC1 and integration qualification | P2/P2R1 `c6d08ff...` / `217f264...` | Logs/builds yes | Yes with a P1 reference checkout |
| `eda/` | Sanitized DC/PT methodology | RFIC P2R1 publication bundle | Reports/sessions yes; scripts no | Yes in a licensed compatible environment |
| `docs/asic/` | Sanitized timing/area interpretation | RFIC P2R1 publication bundle | No | Derived from public CSVs |
| `results/public/` | Compact qualified result tables | All stages | Yes, curated | Yes by rerunning the corresponding stage |

Ellipses in short commit labels are display abbreviations only; full commit IDs
are listed in `docs/origin_provenance.md` and the experiment READMEs.
RFIC scripts preserve the sanitized bundle content; ten files received only a
single-EOF-newline normalization so the publication passes `git diff --check`.
