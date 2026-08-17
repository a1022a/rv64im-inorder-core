# 01 — Branch predictor DSE

Conditional-predictor replay and error morphology showed observable branch
recovery. Capacity was swept at 512, 1024, and 2048 entries. FIB errors were
602, 603, and 603; Bubble errors were 104, 104, and 104. Capacity scaling gave
essentially no benefit, so it was not the limiting lever.

Decision: `STOP_BRANCH_DSE`. Status: rejected, retained for evidence. RTL
implementation: none.

Source class: branch modeling, frozen commit
`a82a98a01eb5cee84eb5497890f16366fb6814e2`.
