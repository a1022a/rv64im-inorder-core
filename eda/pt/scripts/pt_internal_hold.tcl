set RUN_DIR $::env(HOLD_RUN_DIR)
set NETLIST $::env(IMPLEMENTATION_NETLIST)
set STDCELL_DB $::env(FAST_MIN_STDCELL_DB)
set SRAM_DB $::env(FAST_MIN_SRAM_DB)
set SOURCE_SDC $::env(SOURCE_SDC)
set TOP rv64im_core_top
set SRAM_REF $::env(SRAM_MACRO_REF)
set STATUS_FILE "$RUN_DIR/metadata/pt_internal_hold.env"
set CSV_FILE "$RUN_DIR/reports/fast_min_hold_paths.csv"

proc swrite {mode line} {
    global STATUS_FILE
    set fp [open $STATUS_FILE $mode]
    puts $fp $line
    close $fp
}
proc sappend {line} { swrite a $line }

proc safe_attr {obj attr} {
    if {[catch {set v [get_attribute $obj $attr]}]} { return NOT_AVAILABLE }
    if {$v eq ""} { return NOT_AVAILABLE }
    return $v
}
proc object_name {obj} {
    if {[catch {set v [get_object_name $obj]}]} { return NOT_AVAILABLE }
    if {$v eq ""} { return NOT_AVAILABLE }
    return $v
}
proc path_has_sram {path} {
    global SRAM_REF
    foreach_in_collection tp [get_attribute $path points] {
        set obj [get_attribute $tp object]
        set cells [get_cells -quiet -of_objects $obj]
        foreach_in_collection c $cells {
            if {[safe_attr $c ref_name] eq $SRAM_REF} { return 1 }
        }
    }
    return 0
}
proc endpoint_is_sram {path} {
    global SRAM_REF
    set ep [get_attribute $path endpoint]
    foreach_in_collection c [get_cells -quiet -of_objects $ep] {
        if {[safe_attr $c ref_name] eq $SRAM_REF} { return 1 }
    }
    return 0
}
proc startpoint_is_sram {path} {
    global SRAM_REF
    set sp [get_attribute $path startpoint]
    foreach_in_collection c [get_cells -quiet -of_objects $sp] {
        if {[safe_attr $c ref_name] eq $SRAM_REF} { return 1 }
    }
    return 0
}
proc classify_path {path} {
    set sp [object_name [get_attribute $path startpoint]]
    set ep [object_name [get_attribute $path endpoint]]
    set sp_port [expr {[sizeof_collection [get_ports -quiet $sp]] > 0}]
    set ep_port [expr {[sizeof_collection [get_ports -quiet $ep]] > 0}]
    if {$sp_port && $ep_port} { return INPUT_TO_OUTPUT }
    if {$sp_port} { return INPUT_TO_REG }
    if {$ep_port} { return REG_TO_OUTPUT }
    if {[startpoint_is_sram $path]} { return SRAM_TO_REG }
    if {[endpoint_is_sram $path]} { return REG_TO_SRAM }
    if {[path_has_sram $path]} { return SRAM_RELATED_OTHER }
    set both [string tolower "$sp $ep"]
    if {[regexp {(^|[/_])(rst|rstn|reset)([/_\[]|$)|/cdn$|/sdn$} $both]} { return RESET_PATH }
    if {[regexp {ctrl|control|flush|stall|redirect|valid|ready|branch|hazard|intr} $both]} { return CONTROL_PATH }
    return REG_TO_REG
}
proc path_cell_count {path} {
    array set seen {}
    foreach_in_collection tp [get_attribute $path points] {
        set obj [get_attribute $tp object]
        foreach_in_collection c [get_cells -quiet -of_objects $obj] {
            set seen([get_object_name $c]) 1
        }
    }
    return [array size seen]
}
proc csv_sanitize {text} {
    regsub -all {,} $text {;} text
    regsub -all {\n} $text { } text
    return $text
}
proc extract_paths {paths limit} {
    global CSV_FILE
    set fp [open $CSV_FILE w]
    puts $fp "path_index,slack_ns,arrival_ns,required_ns,startpoint,endpoint,launch_clock,capture_clock,path_group,path_class,sram_involved,path_cell_count"
    set idx 0
    foreach_in_collection p $paths {
        incr idx
        if {$idx > $limit} { break }
        set slack [safe_attr $p slack]
        set arrival [safe_attr $p arrival]
        set required [safe_attr $p required]
        set sp [csv_sanitize [object_name [get_attribute $p startpoint]]]
        set ep [csv_sanitize [object_name [get_attribute $p endpoint]]]
        set lc [csv_sanitize [object_name [get_attribute $p startpoint_clock]]]
        set cc [csv_sanitize [object_name [get_attribute $p endpoint_clock]]]
        set pg [csv_sanitize [object_name [get_attribute $p path_group]]]
        set cls [classify_path $p]
        set sram [expr {[path_has_sram $p] ? "YES" : "NO"}]
        set depth [path_cell_count $p]
        puts $fp "$idx,$slack,$arrival,$required,$sp,$ep,$lc,$cc,$pg,$cls,$sram,$depth"
    }
    close $fp
    return $idx
}

proc run_hold {} {
    global RUN_DIR NETLIST STDCELL_DB SRAM_DB SOURCE_SDC TOP SRAM_REF STATUS_FILE sh_product_version
    swrite w "P2R1_COMMIT=217f2640b170f12f276e711a9aa08ac50cd7c946"
    sappend "P2R1_TREE=d917e4c2df7f0d3aef05f7d3b1cc27dbd591cc41"
    sappend "P2R1_PARENT_COMMIT=c6d08ff57f0e8cdaf734aa8b8d63a6b569850af2"
    sappend "TOP_MODULE=$TOP"
    sappend "PT_VERSION=$sh_product_version"
    sappend "ANALYSIS_TYPE=PRE_LAYOUT_INTERNAL_HOLD_CHARACTERIZATION"
    sappend "IMPLEMENTATION_ROLE=PILOT_INTERNAL_HOLD_CHARACTERIZATION"
    sappend "IMPLEMENTATION_SYNTHESIS_PERIOD_NS=2.0"
    sappend "PT_LIBRARY_READ=FAIL"
    sappend "PT_DESIGN_READ=FAIL"
    sappend "PT_LINK=FAIL"
    sappend "FORMAL_HOLD_ANALYSIS_RUN=NO"

    foreach f [list $NETLIST $STDCELL_DB $SRAM_DB $SOURCE_SDC] {
        if {![file readable $f]} { error "required input unreadable: $f" }
    }
    set_app_var search_path [list [file dirname $NETLIST]]
    set_app_var link_path [list "*" $STDCELL_DB $SRAM_DB]
    read_verilog $NETLIST
    if {[sizeof_collection [get_designs -quiet $TOP]] != 1} { error "top missing after read_verilog" }
    sappend "PT_DESIGN_READ=PASS"
    current_design $TOP
    if {![link_design $TOP]} { error "link_design returned false" }
    sappend "PT_LINK=PASS"

    set sc_libs [get_libs -quiet $::env(STDCELL_MIN_LIB_NAME)]
    set sr_libs [get_libs -quiet $::env(SRAM_MIN_LIB_NAME)]
    if {[sizeof_collection $sc_libs] != 1 || [sizeof_collection $sr_libs] != 1} { error "fast/min library identity mismatch" }
    sappend "PT_LIBRARY_READ=PASS"

    set macros [get_cells -hierarchical -quiet -filter "ref_name == $SRAM_REF"]
    set macro_count [sizeof_collection $macros]
    set macro_lib_cells [get_lib_cells -quiet */$SRAM_REF]
    set arc_count [sizeof_collection [get_lib_timing_arcs -quiet -of_objects $macro_lib_cells]]
    if {$macro_count != 32 || [sizeof_collection $macro_lib_cells] != 1 || $arc_count == 0} { error "SRAM link/timing mismatch count=$macro_count arcs=$arc_count" }
    set all_bb [get_cells -hierarchical -quiet -filter "is_black_box == true"]
    set macro_bb [get_cells -hierarchical -quiet -filter "is_black_box == true && ref_name == $SRAM_REF"]
    set unexpected_bb [remove_from_collection $all_bb $macro_bb]
    set unresolved_count [sizeof_collection $unexpected_bb]
    if {$unresolved_count != 0} { error "unexpected unresolved references: [get_object_name $unexpected_bb]" }
    sappend "PT_UNRESOLVED_REFERENCE_COUNT=0"
    sappend "PT_SRAM_INSTANCE_COUNT=$macro_count"
    sappend "PT_SRAM_TIMING_ARC_COUNT=$arc_count"

    # Run-local internal-only constraint view, copied exactly from audited source SDC.
    # The source SDC binds the slow/max library and contains only max I/O budgets, so it
    # is not sourced into this fast/min internal-hold scenario.
    create_clock -name core_clk -period 2.0 -waveform {0 1.0} [get_ports clk]
    set_clock_uncertainty 0.0 [get_clocks core_clk]
    set clocks [get_clocks -quiet *]
    set functional_clock_count [sizeof_collection $clocks]
    set generated_clock_count 0
    foreach_in_collection clk $clocks {
        if {![catch {set isgen [get_attribute $clk is_generated]}] && $isgen} { incr generated_clock_count }
    }
    set period [get_attribute [get_clocks core_clk] period]
    set waveform [get_attribute [get_clocks core_clk] waveform]
    set uncertainty 0.0
    sappend "CLOCK_NAME=core_clk"
    sappend "CLOCK_PERIOD_NS=$period"
    sappend "CLOCK_WAVEFORM=$waveform"
    sappend "CLOCK_UNCERTAINTY_NS=$uncertainty"
    sappend "FUNCTIONAL_CLOCK_DOMAIN_COUNT=$functional_clock_count"
    sappend "GENERATED_CLOCK_COUNT=$generated_clock_count"

    set all_regs [all_registers]
    set clocked_regs [all_registers -clock core_clk]
    set unclocked_regs [remove_from_collection $all_regs $clocked_regs]
    set unclocked_count [sizeof_collection $unclocked_regs]
    sappend "TOTAL_REGISTER_ENDPOINT_COUNT=[sizeof_collection $all_regs]"
    sappend "CLOCKED_REGISTER_ENDPOINT_COUNT=[sizeof_collection $clocked_regs]"
    sappend "UNCLOCKED_INTERNAL_REGISTER_COUNT=$unclocked_count"
    redirect -file "$RUN_DIR/reports/fast_min_unclocked_registers.rpt" { query_objects $unclocked_regs }

    redirect -file "$RUN_DIR/reports/fast_min_check_timing.rpt" { check_timing -verbose }
    redirect -file "$RUN_DIR/reports/fast_min_analysis_coverage.rpt" { report_analysis_coverage }
    redirect -file "$RUN_DIR/reports/fast_min_analysis_coverage_hold_untested.rpt" { report_analysis_coverage -status_details {untested} -check_type {hold} -sort_by name }
    redirect -file "$RUN_DIR/metadata/pin_attributes.rpt" { list_attributes -application -class pin }

    set all_internal_paths [get_timing_paths -delay_type min -slack_lesser_than 1000000.0 -max_paths 100000 -nworst 1]
    set internal_path_count [sizeof_collection $all_internal_paths]
    if {$internal_path_count == 0} { error "no constrained internal min paths" }
    set violating [get_timing_paths -delay_type min -slack_lesser_than 0.0 -max_paths 100000 -nworst 1]
    set violating_count [sizeof_collection $violating]
    set tns 0.0
    array set violating_endpoints {}
    set sram_violation_count 0
    set reg_to_sram_violation_count 0
    set sram_to_reg_violation_count 0
    foreach_in_collection p $violating {
        set slack [get_attribute $p slack]
        set tns [expr {$tns + $slack}]
        set ep [object_name [get_attribute $p endpoint]]
        set violating_endpoints($ep) 1
        set cls [classify_path $p]
        if {[path_has_sram $p]} { incr sram_violation_count }
        if {$cls eq "REG_TO_SRAM"} { incr reg_to_sram_violation_count }
        if {$cls eq "SRAM_TO_REG"} { incr sram_to_reg_violation_count }
    }
    set violating_endpoint_count [array size violating_endpoints]

    set worst [index_collection $all_internal_paths 0]
    set wns [get_attribute $worst slack]
    set worst_sp [object_name [get_attribute $worst startpoint]]
    set worst_ep [object_name [get_attribute $worst endpoint]]
    set worst_class [classify_path $worst]
    set worst_sram [expr {[path_has_sram $worst] ? "YES" : "NO"}]
    set worst_depth [path_cell_count $worst]
    set worst_launch_clock [object_name [get_attribute $worst startpoint_clock]]
    set worst_capture_clock [object_name [get_attribute $worst endpoint_clock]]

    if {$violating_count > 0} {
        set report_paths $violating
    } else {
        set report_paths $all_internal_paths
    }
    set extracted [extract_paths $report_paths 100]
    redirect -file "$RUN_DIR/reports/fast_min_hold_worst_paths.rpt" {
        report_timing -delay_type min -path_type full -input_pins -nets -transition_time -capacitance -slack_lesser_than 1000000.0 -max_paths 100 -nworst 1
    }
    redirect -file "$RUN_DIR/reports/fast_min_hold_violating_paths.rpt" {
        report_timing -delay_type min -path_type full -input_pins -nets -transition_time -capacitance -slack_lesser_than 0.0 -max_paths 100 -nworst 1
    }
    set sram_out_pins [get_pins -quiet -of_objects $macros -filter "direction == out"]
    set sram_in_pins [get_pins -quiet -of_objects $macros -filter "direction == in"]
    redirect -file "$RUN_DIR/reports/fast_min_hold_sram_to_reg_raw.rpt" {
        report_timing -delay_type min -from $sram_out_pins -path_type full -input_pins -nets -transition_time -capacitance -slack_lesser_than 1000000.0 -max_paths 100 -nworst 1
    }
    redirect -file "$RUN_DIR/reports/fast_min_hold_reg_to_sram_raw.rpt" {
        report_timing -delay_type min -to $sram_in_pins -path_type full -input_pins -nets -transition_time -capacitance -slack_lesser_than 1000000.0 -max_paths 100 -nworst 1
    }

    sappend "FORMAL_HOLD_ANALYSIS_RUN=YES"
    sappend "CONSTRAINED_INTERNAL_MIN_PATH_COUNT=$internal_path_count"
    sappend "INTERNAL_HOLD_WNS_NS=$wns"
    sappend "INTERNAL_HOLD_TNS_NS=$tns"
    sappend "INTERNAL_HOLD_VIOLATING_PATH_COUNT=$violating_count"
    sappend "INTERNAL_HOLD_VIOLATING_ENDPOINT_COUNT=$violating_endpoint_count"
    sappend "WORST_HOLD_STARTPOINT=$worst_sp"
    sappend "WORST_HOLD_ENDPOINT=$worst_ep"
    sappend "WORST_HOLD_SLACK_NS=$wns"
    sappend "WORST_HOLD_LAUNCH_CLOCK=$worst_launch_clock"
    sappend "WORST_HOLD_CAPTURE_CLOCK=$worst_capture_clock"
    sappend "WORST_HOLD_PATH_CLASS=$worst_class"
    sappend "WORST_HOLD_SRAM_INVOLVED=$worst_sram"
    sappend "WORST_HOLD_PATH_CELL_COUNT=$worst_depth"
    sappend "SRAM_RELATED_HOLD_VIOLATION_COUNT=$sram_violation_count"
    sappend "SRAM_TO_REG_HOLD_VIOLATION_COUNT=$sram_to_reg_violation_count"
    sappend "REG_TO_SRAM_TIMING_CHECK_VIOLATION_COUNT=$reg_to_sram_violation_count"
    sappend "WORST_PATHS_EXTRACTED=$extracted"
    sappend "PT_INTERNAL_HOLD_RUN=PASS"
}

set rc [catch {run_hold} message options]
if {$rc} {
    sappend "PT_INTERNAL_HOLD_RUN=FAIL"
    sappend "PT_FATAL_ERROR=$message"
    puts stderr "PT_INTERNAL_HOLD_FAIL=$message"
} else {
    puts "PT_INTERNAL_HOLD_RUN=PASS"
}
quit
