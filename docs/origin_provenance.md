# Origin and provenance

The publication baseline commit is
`00439d9731c85bcf46e6aa717bf59708b9f1c293`. Its tree is identical to the
canonical engineering baseline `e9b27cd17077b7917c6612dae5403e1d1d47d1b6`
(tree `56407a30556a0018d4ebe8375db4093d120af560`).

| Stage | Frozen commit | Published material |
|---|---|---|
| Attribution and branch modeling | `a82a98a01eb5cee84eb5497890f16366fb6814e2` | observer, branch replay/sweep, notes |
| Cache C0/C1 | `68988e93f3be248a10a31819ee56084437ed4bd1` | counter method and qualification |
| Cache C2 | `82172832eb28517a7a7c88b0d06b37be636ad77a` | exact tree-PLRU replay and capacity sweep |
| Load-use modeling | `a3386e568c42f46568170626f0e774441fd21d91` | dependency analysis and counterfactual |
| Load-use P1 | `4858651e70bd41fb9cc789a4b09a3f0de624d46a` | accepted bypass, runners, tests |
| Divider timing audit | `1ca28bd8e7ea2f4e362922d5ef895ab37912cbf8` | RTL/cone audit and candidate comparison |
| P2 DRC1 | `c6d08ff57f0e8cdaf734aa8b8d63a6b569850af2` | functional DRC1 and VER-956 evidence |
| P2R1 | `217f2640b170f12f276e711a9aa08ac50cd7c946` | final accepted RTL and closure evidence |

The final `rtl/` is an exact copy of the P2R1 frozen source, not a reconstruction
from prose. The RFIC content under `eda/`, `docs/asic/`, and
`results/public/asic/` comes from a checksum-verified sanitized publication
bundle. Copyright, attribution, and third-party notices present in source files
remain intact. Generated output and proprietary technology data are excluded.
