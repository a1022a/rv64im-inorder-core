# I-cache 64-set Directed Validation

`tests/custom/icache_64set_directed.S` is linked by
`tests/custom/icache_64set_directed.ld` so its CPU-executed target functions
are at these independent 32-byte instruction lines:

| Target | Address | `address[10:5]` | old `address[9:5]` | Dynamic result |
| --- | --- | ---: | ---: | --- |
| A | `0x80000400` | 32 | 0 | executed; set 32, way 0 |
| A + `0x400` | `0x80000800` | 0 | 0 | executed; set 0, way 2 |
| A + `0x800` | `0x80000c00` | 32 | 0 | executed; set 32, way 2 |
| A + `0xc00` | `0x80001000` | 0 | 0 | executed; set 0, way 3 |
| A + `0x1000` | `0x80001400` | 32 | 0 | executed; set 32, way 1 |

The program calls all five targets, checks its execution count, then ends with
`ebreak`. The isolated simulation-only monitor reads the Verilator I-cache
tag/valid arrays after execution. It does not alter RTL or the standard build:
the monitor is compiled only when `ICACHE_64SET_MONITOR` is defined by
`scripts/run_icache_64set_directed.sh`.

The dynamic log records all five lines as executed and resident: a 3+2 split
between set 32 and set 0. Under the former 32-set index all five lines have
index 0 and cannot coexist in a four-way set. NEMU DiffTest was loaded, the
program reached `HIT GOOD TRAP`, and the monitor reported PASS. This is dynamic
evidence that address bit 10 participates in instruction-cache set selection.

ICACHE_64SET_DIRECTED=PASS
