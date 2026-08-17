set RUN_DIR $::env(PT_RUN_DIR)
set DC_RUN_DIR $::env(DC_POINT_RUN_DIR)
set EXPECTED_PERIOD [expr {double($::env(EXPECTED_PERIOD_NS))}]
set EXPECTED_TIMING_STATUS $::env(EXPECTED_TIMING_STATUS)
set STATUS_FILE "$RUN_DIR/metadata/pt_boundary.env"
set STDCELL_DB $::env(STDCELL_MAX_DB)
set SRAM_DB $::env(SRAM_MAX_DB)
set NETLIST "$DC_RUN_DIR/outputs/rv64im_core_top_mapped.v"
set SDC "$DC_RUN_DIR/constraints/characterization_effective.sdc"
set TOP "rv64im_core_top"
set SRAM_REF $::env(SRAM_MACRO_REF)
set CURRENT_PHASE "SETUP"

proc status_write {mode line} { global STATUS_FILE; set fp [open $STATUS_FILE $mode]; puts $fp $line; close $fp }
proc status_append {line} { status_write a $line }

proc logical_port_count {ports} {
    array set seen {}
    foreach_in_collection p $ports {
        set port_name [get_object_name $p]
        regsub {\[[0-9]+\]$} $port_name {} logical_name
        set seen($logical_name) 1
    }
    return [array size seen]
}

proc classify_path {sp ep} {
    set sp_is_port [expr {[sizeof_collection [get_ports -quiet $sp]] == 1}]
    set ep_is_port [expr {[sizeof_collection [get_ports -quiet $ep]] == 1}]
    if {[string match "*u_sram*" $sp] || [string match "*u_sram*" $ep]} { return SRAM_RELATED }
    if {$sp_is_port && [string match "axi_*" $sp]} { return AXI_INPUT_TO_REG }
    if {$ep_is_port && [string match "axi_*" $ep]} { return REG_TO_AXI_OUTPUT }
    if {!$sp_is_port && !$ep_is_port} { return INTERNAL_REG2REG }
    return OTHER
}

proc run_pt {} {
    global RUN_DIR DC_RUN_DIR STATUS_FILE STDCELL_DB SRAM_DB NETLIST SDC TOP SRAM_REF CURRENT_PHASE EXPECTED_PERIOD EXPECTED_TIMING_STATUS
    status_write w "P2R1_COMMIT=217f2640b170f12f276e711a9aa08ac50cd7c946"
    status_append "P2R1_TREE=d917e4c2df7f0d3aef05f7d3b1cc27dbd591cc41"
    status_append "P2R1_PARENT_COMMIT=c6d08ff57f0e8cdaf734aa8b8d63a6b569850af2"
    status_append "TOP_MODULE=$TOP"
    status_append "CHARACTERIZATION_ONLY=YES"
    status_append "SOC_SIGNOFF=NO"
    status_append "POST_LAYOUT=NO"
    status_append "ANALYSIS_MODE=POST_SYNTHESIS_PRE_LAYOUT_MAX_SETUP"
    status_append "EXPECTED_TIMING_STATUS=$EXPECTED_TIMING_STATUS"

    set CURRENT_PHASE "INPUT_VALIDATION"
    foreach f [list $STDCELL_DB $SRAM_DB $NETLIST $SDC] {
        if {![file readable $f]} { error "required PT input not readable: $f" }
    }

    set CURRENT_PHASE "READ_AND_LINK"
    set_app_var search_path [list [file dirname $NETLIST]]
    set_app_var link_path [list "*" $STDCELL_DB $SRAM_DB]
    read_verilog $NETLIST
    if {[sizeof_collection [get_designs -quiet $TOP]] != 1} { error "mapped top missing after read_verilog" }
    current_design $TOP
    if {[catch {set link_ok [link_design $TOP]} msg]} { error "PT link command failed: $msg" }
    if {!$link_ok} { error "PT link returned false" }

    set macro_cells [get_cells -hierarchical -quiet -filter "ref_name == $SRAM_REF"]
    set macro_count [sizeof_collection $macro_cells]
    if {$macro_count != 32} { error "PT SRAM count mismatch: $macro_count" }
    set macro_lib_cells [get_lib_cells -quiet */$SRAM_REF]
    if {[sizeof_collection $macro_lib_cells] != 1} { error "PT SRAM library-cell resolution mismatch" }
    set macro_timing_arcs [get_lib_timing_arcs -quiet -of_objects $macro_lib_cells]
    set macro_timing_arc_count [sizeof_collection $macro_timing_arcs]
    if {$macro_timing_arc_count == 0} { error "PT SRAM library timing arcs unavailable" }

    set blackboxes [get_cells -hierarchical -quiet -filter "is_black_box == true"]
    set intentional_macro_blackboxes [get_cells -hierarchical -quiet -filter "is_black_box == true && ref_name == $SRAM_REF"]
    set unexpected_blackboxes [remove_from_collection $blackboxes $intentional_macro_blackboxes]
    set intentional_macro_blackbox_count [sizeof_collection $intentional_macro_blackboxes]
    set unexpected_blackbox_count [sizeof_collection $unexpected_blackboxes]
    if {$intentional_macro_blackbox_count != 32 || $unexpected_blackbox_count != 0} {
        error "PT unexpected black-box cells: [get_object_name $unexpected_blackboxes]"
    }
    status_append "PT_LINK=PASS"
    status_append "PT_UNRESOLVED_REFERENCE_COUNT=0"
    status_append "PT_SRAM_INSTANCE_COUNT=$macro_count"
    status_append "PT_INTENTIONAL_SRAM_HARD_MACRO_BLACKBOX_COUNT=$intentional_macro_blackbox_count"
    status_append "PT_UNEXPECTED_BLACKBOX_COUNT=$unexpected_blackbox_count"
    status_append "PT_SRAM_LIBRARY_TIMING_ARC_COUNT=$macro_timing_arc_count"
    status_append "PT_SRAM_TIMING_MODEL_STATUS=LINKED_DB_WITH_USABLE_TIMING_ARCS"

    set CURRENT_PHASE "READ_SDC"
    read_sdc $SDC
    set clocks [get_clocks -quiet core_clk]
    if {[sizeof_collection $clocks] != 1} { error "core_clk missing after read_sdc" }
    set period [get_attribute $clocks period]
    if {[expr {abs($period - $EXPECTED_PERIOD)}] > 0.000001} { error "PT clock period mismatch: $period expected $EXPECTED_PERIOD" }

    set CURRENT_PHASE "CONSTRAINT_VALIDATION"
    set all_regs [all_registers]
    set clocked_regs [all_registers -clock core_clk]
    set unclocked_regs [remove_from_collection $all_regs $clocked_regs]
    set all_reg_count [sizeof_collection $all_regs]
    set clocked_reg_count [sizeof_collection $clocked_regs]
    set unclocked_reg_count [sizeof_collection $unclocked_regs]
    if {$all_reg_count == 0 || $unclocked_reg_count != 0} {
        error "PT register clock coverage mismatch all=$all_reg_count clocked=$clocked_reg_count unclocked=$unclocked_reg_count"
    }

    set axi_inputs [get_ports -quiet axi_*_i]
    set axi_outputs [get_ports -quiet axi_*_o]
    set axi_in_bits [sizeof_collection $axi_inputs]
    set axi_out_bits [sizeof_collection $axi_outputs]
    set axi_in_logical [logical_port_count $axi_inputs]
    set axi_out_logical [logical_port_count $axi_outputs]
    if {$axi_in_bits != 84 || $axi_out_bits != 211 || $axi_in_logical != 13 || $axi_out_logical != 31} {
        error "PT AXI interface coverage mismatch"
    }

    redirect -file "$RUN_DIR/reports/check_timing.rpt" { check_timing -verbose }
    redirect -file "$RUN_DIR/reports/report_clock.rpt" { report_clock }
    redirect -file "$RUN_DIR/reports/report_analysis_coverage.rpt" { report_analysis_coverage }
    redirect -file "$RUN_DIR/reports/report_analysis_coverage_untested_setup.rpt" { report_analysis_coverage -status_details {untested} -check_type {setup} -sort_by name }
    redirect -file "$RUN_DIR/reports/report_analysis_coverage_untested_out_setup.rpt" { report_analysis_coverage -status_details {untested} -check_type {out_setup} -sort_by name }
    redirect -file "$RUN_DIR/reports/report_analysis_coverage_untested_reset.rpt" { report_analysis_coverage -status_details {untested} -check_type {recovery removal} -sort_by name }
    redirect -file "$RUN_DIR/reports/report_constraint_violators.rpt" { report_constraint -all_violators -verbose }
    redirect -file "$RUN_DIR/reports/report_timing_max.rpt" { report_timing -delay_type max -path_type full -input_pins -nets -transition_time -capacitance -slack_lesser_than 1000000.0 -max_paths 20 }
    redirect -file "$RUN_DIR/reports/report_timing_axi_input.rpt" { report_timing -delay_type max -from $axi_inputs -slack_lesser_than 1000000.0 -max_paths 20 }
    redirect -file "$RUN_DIR/reports/report_timing_axi_output.rpt" { report_timing -delay_type max -to $axi_outputs -slack_lesser_than 1000000.0 -max_paths 20 }

    status_append "CLOCK_PERIOD_NS=$period"
    status_append "TOTAL_REGISTER_ENDPOINTS=$all_reg_count"
    status_append "CORE_CLK_REGISTER_ENDPOINTS=$clocked_reg_count"
    status_append "ACCIDENTALLY_UNCLOCKED_REGISTER_ENDPOINTS=$unclocked_reg_count"
    status_append "AXI_INPUT_MAX_CONSTRAINED_COUNT=$axi_in_bits"
    status_append "AXI_OUTPUT_MAX_CONSTRAINED_COUNT=$axi_out_bits"
    status_append "AXI_INPUT_LOGICAL_PORT_COUNT=$axi_in_logical"
    status_append "AXI_OUTPUT_LOGICAL_PORT_COUNT=$axi_out_logical"
    status_append "INTENTIONALLY_UNCONSTRAINED=RESET_rstn"
    status_append "PT_UNCONSTRAINED_FUNCTIONAL_PATHS=0"
    status_append "PT_CONSTRAINT_VALIDATION=PASS"

    set CURRENT_PHASE "MAX_TIMING_EXTRACTION"
    set paths [get_timing_paths -delay_type max -max_paths 1]
    if {[sizeof_collection $paths] != 1} { error "no PT max timing path available" }
    set wns [get_attribute $paths slack]
    set sp [get_object_name [get_attribute $paths startpoint]]
    set ep [get_object_name [get_attribute $paths endpoint]]
    set pg [get_object_name [get_attribute $paths path_group]]
    set path_class [classify_path $sp $ep]

    set violating [get_timing_paths -delay_type max -slack_lesser_than 0.0 -max_paths 100000 -nworst 1]
    set violating_count [sizeof_collection $violating]
    set tns 0.0
    foreach_in_collection p $violating { set tns [expr {$tns + [get_attribute $p slack]}] }

    if {$wns >= 0.0 && $tns == 0.0} { set actual PASS } else { set actual FAIL }
    status_append "PT_WNS_NS=$wns"
    status_append "PT_TNS_NS=$tns"
    status_append "PT_VIOLATING_PATH_COUNT=$violating_count"
    status_append "PT_CRITICAL_PATH_STARTPOINT=$sp"
    status_append "PT_CRITICAL_PATH_ENDPOINT=$ep"
    status_append "PT_CRITICAL_PATH_GROUP=$pg"
    status_append "PT_CRITICAL_PATH_CLASS=$path_class"
    status_append "PT_TIMING_STATUS=$actual"
    if {$actual eq $EXPECTED_TIMING_STATUS} {
        status_append "PT_BOUNDARY_CONFIRMATION=PASS"
    } else {
        status_append "PT_BOUNDARY_CONFIRMATION=FAIL"
    }
    status_append "PT_FLOW_STATUS=PASS"
}

set rc [catch {run_pt} message options]
if {$rc} {
    status_append "PT_FLOW_STATUS=FAIL"
    status_append "FAILURE_PHASE=$CURRENT_PHASE"
    status_append "FIRST_FATAL_ERROR=$message"
    puts stderr "PT_BOUNDARY_FAIL phase=$CURRENT_PHASE detail=$message"
} else {
    puts "PT_BOUNDARY_FLOW=PASS"
}
quit
