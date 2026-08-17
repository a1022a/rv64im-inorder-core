# A2 Cache Counter Semantics

## Event and cycle rules

An event increments once on its named accepted edge; occupancy increments once
per sampled ROI cycle. Miss is never `req && !hit` over a held transaction.

| Counter | Exact semantic |
|---|---|
| I/D `CACHE_ACCESS` | accepted `req_vld` |
| I/D `CACHE_HIT` | accepted `req_hit` |
| I/D `CACHE_MISS` / `MISS_ALLOCATED_IN_ROI` | accepted `req_miss` |
| D load/store access/hit/miss | accepted event qualified by `i_mem_wen` |
| I/D `CACHE_REFILL` | refill-completion event (`rbus_done`, or RBUS exit in synthesis-top harness) |
| D dirty eviction | `wbus_en` on a dirty valid victim |
| D writeback | completed WBUS transaction (`wbus_done`, or WBUS exit) |
| miss/writeback stall cycles | sampled RBUS/WBUS occupancy |
| D total stall | WBUS or RBUS or response backpressure |
| I total stall | RBUS or response backpressure; WBUS is unreachable for I$ |

`RETIRED_INSTRUCTION`, IPC, and MPKI are `NOT_QUALIFIED`. Phase 9 proved
`wb_sign` only as `PARTIAL_RETIREMENT_EVENT`; this phase reuses it solely for
FIB/bubble PC-marker ROI and reports `writeback_observations`, not retirement.
GOL synthesis-top runs have no writeback observation port.

## ROI boundaries

FIB/bubble counters reset after the start-marker `wb_sign` and stop before the
end marker. GOL counters exclude the start `csrr cycle` edge and include the
end `csrr cycle` edge, exactly matching `mcycle_end - mcycle_start`.

Allocation, start, and completion are independently counted in ROI. Thus a
pre-ROI outstanding miss completing inside ROI appears only in completion;
an in-ROI allocation completing after ROI appears only in allocation/start.
FIB measured 19 I$ allocations but 20 completions, proving one carry-in refill.
Stall cycles always count only sampled cycles inside ROI.

## Attribution and upper bounds

The existing mutually-exclusive priority is retained: D-cache/memory,
divider, branch recovery, dependency, I-cache, other. Perfect-cache bounds
subtract only exclusive D and/or I categories, so overlapping raw levels are
not double-subtracted. They are counterfactual upper bounds, not RTL forecasts.
