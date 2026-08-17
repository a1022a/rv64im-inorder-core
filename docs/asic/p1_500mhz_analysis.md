# P1 500 MHz analysis

P1 commit `4858651e70bd41fb9cc789a4b09a3f0de624d46a` missed setup by 1.319 ps. DC reported WNS -0.00131893 ns, TNS -0.017060514 ns, and 41 violations; PT reported -0.001319 ns, -0.016545 ns, and 41 violations. The worst family was `DIV_RESULT_TO_ID_ALU_RS1_OPERAND_REGISTER`. Internal hold passed at +0.037408 ns. The direct load-use probe had +0.173345 ns slack and was not in the top 20, proving the P1 failure was not caused by the new load-use path. Area was 89473.314 standard-cell units, 129608 cells, 274018.095248 total, and 32 SRAMs.
