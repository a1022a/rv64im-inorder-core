# Publication-safe reconstruction of the qualified block/interface methodology.
# Supply CLOCK_PERIOD_NS and GENERIC_DRIVING_CELL in the caller environment.
set CHARACTERIZATION_CLOCK_PERIOD_NS $::env(CLOCK_PERIOD_NS)
set CHARACTERIZATION_INPUT_MAX_NS [expr {$CHARACTERIZATION_CLOCK_PERIOD_NS * 0.25}]
set CHARACTERIZATION_OUTPUT_MAX_NS [expr {$CHARACTERIZATION_CLOCK_PERIOD_NS * 0.25}]

create_clock -name core_clk -period $CHARACTERIZATION_CLOCK_PERIOD_NS [get_ports clk]
set_clock_uncertainty 0.0 [get_clocks core_clk]

set data_inputs [remove_from_collection [all_inputs] [get_ports {clk rstn}]]
set data_outputs [all_outputs]
set_input_delay -max $CHARACTERIZATION_INPUT_MAX_NS -clock core_clk $data_inputs
set_output_delay -max $CHARACTERIZATION_OUTPUT_MAX_NS -clock core_clk $data_outputs
set_driving_cell -lib_cell $::env(GENERIC_DRIVING_CELL) $data_inputs
set_load $::env(GENERIC_FO4_OUTPUT_LOAD) $data_outputs

# One functional clock; no generated-clock, clock-gating, CDC, or full-chip claim.
# Reset is asynchronous active-low. AXI is treated as synchronous to core_clk.
# No AXI min-delay model was defined. This is characterization, not signoff SDC.
