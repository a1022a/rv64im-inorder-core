# P2R1 500 MHz closure

P1 improved workload performance but fresh 500 MHz setup failed by 1.319 ps; the load-use path itself had substantial positive slack. Root-cause analysis identified an existing DIV→ID post-result signed-correction cone, so cycle-equivalent DRC1 completion-time signed quotient storage was selected. P2 passed functional qualification but exposed the declaration-order VER-956 compatibility issue. P2R1 commit `217f2640b170f12f276e711a9aa08ac50cd7c946` applied only the declaration move.

Fresh P2R1 DC and standalone PT both pass 2.0 ns: DC WNS +0.0000971556 ns and PT WNS +0.000097 ns, with zero TNS and zero violations. The old DIV→ID family is no longer critical and is absent from the top 20; the worst family migrated to `CSR_CYCLE_COUNTER_REGISTER_TO_CSR_CYCLE_COUNTER_REGISTER`. The load-use probe is +0.129794 ns and outside the top 20. Fast/min internal hold remains passing at +0.037408 ns with no SRAM violations or unconstrained internal endpoints. No P3 is justified.

The final setup margin is extremely thin: +0.097 ps. This is 500 MHz pre-layout synthesized ASIC frontend setup/hold closure under the characterized methodology—not large margin, post-route closure, signoff Fmax, silicon Fmax, or full PPA. Power is not closed.
