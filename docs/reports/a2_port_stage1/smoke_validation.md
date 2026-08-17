# A2 Stage1 Validation

| Gate | Result |
| --- | --- |
| Static | PASS |
| `make doctor` | PASS |
| `make build` | PASS |
| `make run TEST=dummy` | PASS |
| DiffTest active | PASS; NEMU reference loaded and dummy reached GOOD TRAP |
| `make smoke` | FAIL/NOT RUN; approval rejected before execution |

Full regression, synthesis, timing analysis, commit, and push are excluded.
