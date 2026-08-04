# Build And Test Interface

Stable public commands:

- `make doctor`
- `make build`
- `make run TEST=dummy`
- `make smoke`
- `make regress`
- `make release`
- `make clean`

Portable defaults live in `config/default.mk`. Machine-local paths such as the
NEMU reference shared object, dummy image, and external am-kernels artifact
root live in ignored `config/local.mk`.

Phase 5 renamed the active RTL tops to simulation top `rv64im_core_sim_top`
and synthesis top candidate `rv64im_core_top`. Verilator prefix/executable
remains `Vtop`.

`make regress` runs the retained full regression matrix implemented directly by
`scripts/run_regress.sh`; there is no separate regression manifest. The wrapper
reads prebuilt external NEMU and am-kernels artifacts from configured local
paths and writes repository-local logs and temporary artifacts under `out/`.
Ordinary image runs use configurable `REGRESS_TIMEOUT_SEC`, defaulting to `120`.
