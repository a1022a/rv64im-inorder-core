# 05 — Divider timing audit, P2, and P2R1

Fresh 500 MHz P1 STA failed setup by 1.319 ps (WNS -0.001319 ns, TNS
-0.016545 ns, 41 violations). The load-use direct probe passed at +0.173345 ns
and was not in the top 20; the root cone was DIV result forwarding into ID.

Candidates:

- `FEC1_DIV_QUALIFIED_DIRECT_FORWARDING_ROUTE`
- `FEC2_FACTORED_DIV_REM_AND_GENERAL_EX_RESULT_SELECTION`
- `DRC1_COMPLETION_TIME_SIGNED_QUOTIENT_STORAGE`
- microarchitectural fallback: disable same-cycle DIV forwarding

The fallback would add a nominal cycle for an immediate DIV-dependent consumer;
target workloads had dynamic DIV count zero. It was not selected because DRC1
preserves function and cycle behavior. DRC1 was checked with 854 directed cases
covering DIV/DIVU/REM/REMU, DIVW/DIVUW/REMW/REMUW, zero division, signed
overflow, random, back-to-back, stall hold, and dependent consumption. P1/P2
bit-and-ack-cycle equivalence passed.

The patched local NEMU reference raises host FPE for selected zero/overflow
cases and is unreliable for selected signed W-form oracle cases. Those cases
therefore use standalone expected values, P1/P2 bit-and-cycle equivalence, and
W-form self-check integration; this publication does not claim that NEMU covers
all divider corners.

P2 passed functional qualification but DC PRESTO stopped at VER-956 because of
declaration order, so no P2 timing result exists. P2R1 fixes declaration order.
Fresh 500 MHz DC/PT passed: setup WNS +0.000097 ns, hold WNS +0.037408 ns, zero
violations. The DIV-to-ID path left the top 20; the CSR cycle counter became
critical. Decision: stop P3.

Source classes: audit `1ca28bd8e7ea2f4e362922d5ef895ab37912cbf8`, P2
`c6d08ff57f0e8cdaf734aa8b8d63a6b569850af2`, P2R1
`217f2640b170f12f276e711a9aa08ac50cd7c946`.
