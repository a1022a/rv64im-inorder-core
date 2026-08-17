# Branch replay and capacity sweep

The scripts replay observed conditional branches, classify error morphology,
and sweep 512, 1024, and 2048 predictor entries. Results were essentially flat:
FIB errors 602/603/603 and Bubble errors 104/104/104. The experiment proves
branch recovery is observable but rejects predictor capacity as the limiting
lever. No branch RTL variant was implemented.
