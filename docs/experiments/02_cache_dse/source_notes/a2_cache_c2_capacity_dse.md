# A2 Cache C2 Capacity DSE

This is a calibrated software replay, not an RTL cache variant. Ways remain 4,
line size remains 32 bytes, and the exact baseline replacement semantics are
fixed. Only capacity and its derived set count change.

| Workload | 4 KiB / 32 sets | 8 KiB / 64 sets | 16 KiB / 128 sets | 32 KiB / 256 sets |
|---|---:|---:|---:|---:|
| FIB misses | 0 | 0 | 0 | 0 |
| bubble-sort misses | 3 | 3 | 3 | 3 |
| GOL128 misses | 1,016 | 1,016 | 884 | 0 |
| GOL128 writebacks | 1,016 | 1,016 | 884 | 0 |
| GOL256 misses | 4,080 | 4,080 | 4,080 | 4,080 |
| GOL256 writebacks | 4,080 | 4,080 | 4,080 | 4,080 |

For GOL128, 8 to 16 KiB removes 132 misses (12.9921%), while 16 to 32 KiB
removes the remaining 884. Under the C1 measured average penalty assumption,
the whole-workload estimated speedups are only 1.003817x and 1.030153x versus
8 KiB, respectively.

GOL256 is invariant across the complete 4-to-32 KiB sweep. Four KiB also does
not worsen any authorized workload. This is evidence that the observed GOL256
sequence is capacity-insensitive over the tested range and is consistent with
a streaming/compulsory-like pattern; it is not a formal miss-type
classification. GOL128 demonstrates that the same model can expose capacity
sensitivity when it exists.

`CACHE_CAPACITY_DSE_RESULT=GOL128_CAPACITY_SENSITIVE_ABOVE_8K;GOL256_NO_CHANGE_4K_TO_32K`

`CACHE_P1_JUSTIFIED=NO`
