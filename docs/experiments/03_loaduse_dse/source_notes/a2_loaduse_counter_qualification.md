# A2 Load-Use Counter Qualification

The directed ROI completed with DiffTest, good trap, cache invariants, and six
one-cycle exclusive dependency episodes. It covers true load-use via RS1, RS2,
and BOTH; two hit outcomes and one miss outcome; a multiply dependency; an
immediate instruction false `rs2` match; and an x0 false match.

Ordinary ALU producer-to-consumer forwarding creates no dependency stall. CSR
producer-to-consumer also forwards without this interlock. DIV/REM waits in the
separate divider category and its dependent consumer does not enter the
dependency umbrella after completion. Every load outcome is resolved.

The machine-readable raw result is
`${LOCAL_HOME}/rv64im-loaduse-model-scratch/directed/dependency_counter_directed.json`.
The retained report is `reports/loaduse_counter_directed_qualification.rpt`.

`LOADUSE_COUNTER_DIRECTED_QUALIFICATION=PASS`
