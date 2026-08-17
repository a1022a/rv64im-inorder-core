# A2 Cache C2 Replay Semantics

## Trace contract

The trace event is the C0-qualified D-cache accepted request
`u_rv64im_core_dcache.req_vld`, defined by
`i_mem_req_vld & o_mem_req_rdy`. A miss held in the refill/writeback FSM emits
one record, not one record per stall cycle. Because the signal is observed
inside the D-cache instance, CLINT and other decode paths never enter this
trace.

Each CSV row contains a contiguous sequence number, simulator cycle, phase,
32-bit address, LOAD/STORE operation, request mask, and RTL hit/miss/dirty
outcomes. Collection begins at reset. Requests before the existing qualified
ROI boundary are `PRE_ROI`; requests counted by C1 are `ROI`; collection stops
at ROI end. The software model consumes address and operation. RTL outcomes are
used only as calibration oracles.

## Exact baseline organization

- Capacity: 8192 bytes
- Ways: 4
- Line: 32 bytes (`OFFSET_SIZE=5`)
- Sets: 64 (`INDEX_SIZE=6`)
- Index: address bits `[10:5]`
- Tag: address bits `[31:11]`
- Reset: all valid, dirty, tag, and 3-bit PLRU arrays are zero

The model derives sets as `capacity / (ways * line_bytes)`. It uses the line
number modulo sets as the index and the remaining high bits as the tag.

## Replacement and state updates

The RTL does not search for an invalid way. Victim selection always follows
the per-set 3-bit tree state. With PLRU bits `b2:b1:b0`, `b0=0` selects the
way0/way1 subtree and `b1` selects way1 versus way0; `b0=1` selects the
way2/way3 subtree and `b2` selects way3 versus way2. Reset state zero therefore
chooses way0.

Hit and refill-completion update the tree identically for the accessed or
victim way:

- way0: preserve `b2`, set `b1:b0=11`
- way1: preserve `b2`, set `b1:b0=01`
- way2: set `b2=1`, preserve `b1`, set `b0=0`
- way3: set `b2=0`, preserve `b1`, set `b0=0`

A store hit sets dirty. Every miss is write-allocate. A valid dirty victim
starts one writeback transaction before refill. Refill completion sets valid
and tag and updates PLRU. A store refill sets dirty. The RTL does not explicitly
clear the selected way's old dirty bit on a load refill; the replay preserves
that literal state transition. This unusual corner is not idealized away, and
the 8 KiB per-access oracle comparison validates the resulting behavior.

`CACHE_ARCHITECTURE_MODIFIED=NO`

`FUNCTIONAL_RTL_BEHAVIOR_MODIFIED=NO`
