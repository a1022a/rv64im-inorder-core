if {![info exists ::env(SWEEP_POINT_RUN_DIR)] || ![info exists ::env(CHAR_CLK_PERIOD_NS)]} { error "sweep environment variables are required" }
set RUN_DIR $::env(SWEEP_POINT_RUN_DIR)
set CHAR_CLK_PERIOD_NS [expr {double($::env(CHAR_CLK_PERIOD_NS))}]
set STATUS_FILE "$RUN_DIR/metadata/dc_point.env"
set STDCELL_DB $::env(STDCELL_MAX_DB)
set SRAM_DB $::env(SRAM_MAX_DB)
set TOP "rv64im_core_top"
set SRAM_REF $::env(SRAM_MACRO_REF)
set CURRENT_PHASE "SETUP"

proc status_write {mode line} { global STATUS_FILE; set fp [open $STATUS_FILE $mode]; puts $fp $line; close $fp }
proc status_append {line} { status_write a $line }

proc classify_path {sp ep} {
    if {[string match "*u_sram*" $sp] || [string match "*u_sram*" $ep]} { return SRAM_RELATED }
    set sp_is_port [expr {[sizeof_collection [get_ports -quiet $sp]] == 1}]
    set ep_is_port [expr {[sizeof_collection [get_ports -quiet $ep]] == 1}]
    if {$sp_is_port && [string match "axi_*" $sp]} { return AXI_INPUT_TO_REG }
    if {$ep_is_port && [string match "axi_*" $ep]} { return REG_TO_AXI_OUTPUT }
    if {!$sp_is_port && !$ep_is_port} { return INTERNAL_REG2REG }
    return OTHER
}

proc run_compile {} {
    global RUN_DIR STATUS_FILE STDCELL_DB SRAM_DB TOP SRAM_REF CHAR_CLK_PERIOD_NS CURRENT_PHASE
    status_write w "P2R1_COMMIT=217f2640b170f12f276e711a9aa08ac50cd7c946"
    status_append "P2R1_TREE=d917e4c2df7f0d3aef05f7d3b1cc27dbd591cc41"
    status_append "P2R1_PARENT_COMMIT=c6d08ff57f0e8cdaf734aa8b8d63a6b569850af2"
    status_append "P1_TREE=b289a9a430ffb387d268b43bd08cc08f84022102"
    status_append "OPTIMIZATION=DRC1_COMPLETION_TIME_SIGNED_QUOTIENT_STORAGE"
    status_append "COMPATIBILITY_FIX=DECLARATION_ORDER_ONLY"
    status_append "TOP_MODULE=$TOP"
    status_append "PERIOD_NS=$CHAR_CLK_PERIOD_NS"
    status_append "FREQUENCY_MHZ=[expr {1000.0 / $CHAR_CLK_PERIOD_NS}]"
    status_append "CHARACTERIZATION_ONLY=YES"

    set CURRENT_PHASE "READ_CONSTRAINED_DDC"
    set_app_var target_library [list $STDCELL_DB]
    set_app_var link_library [list "*" $STDCELL_DB $SRAM_DB]
    read_db $STDCELL_DB
    read_db $SRAM_DB
    read_ddc "$RUN_DIR/work/rv64im_core_top_precompile_constrained.ddc"
    current_design $TOP
    if {[catch {set link_ok [link]} msg]} { error "precompile DDC link failed: $msg" }
    if {!$link_ok} { error "precompile DDC link returned false" }
    if {[sizeof_collection [get_clocks -quiet core_clk]] != 1} { error "core_clk missing from constrained DDC" }
    set actual_period [get_attribute [get_clocks core_clk] period]
    if {[expr {abs($actual_period - $CHAR_CLK_PERIOD_NS)}] > 0.000001} { error "constrained DDC period mismatch" }
    if {[sizeof_collection [get_cells -hierarchical -quiet -filter "ref_name == $SRAM_REF"]] != 32} { error "precompile SRAM count not 32" }

    set CURRENT_PHASE "COMPILE_ULTRA"
    if {[catch {set compile_ok [compile_ultra]} msg]} { error "compile_ultra command failed: $msg" }
    if {!$compile_ok} { error "compile_ultra returned false" }
    status_append "DC_COMPILE_ULTRA=PASS"

    set CURRENT_PHASE "POSTCOMPILE_VALIDATION"
    if {[catch {set link_ok [link]} msg]} { error "postcompile link failed: $msg" }
    if {!$link_ok} { error "postcompile link returned false" }
    set unresolved [get_references -quiet -filter "is_unresolved == true"]
    if {[sizeof_collection $unresolved] != 0} { error "postcompile unresolved references" }
    set macro_cells [get_cells -hierarchical -quiet -filter "ref_name == $SRAM_REF"]
    set macro_count [sizeof_collection $macro_cells]
    if {$macro_count != 32} { error "postcompile SRAM count mismatch: $macro_count" }
    set icache_macro_cells [filter_collection $macro_cells "full_name =~ *u_rv64im_core_icache*"]
    set dcache_macro_cells [filter_collection $macro_cells "full_name =~ *u_rv64im_core_dcache*"]
    set icache_macro_count [sizeof_collection $icache_macro_cells]
    set dcache_macro_count [sizeof_collection $dcache_macro_cells]
    if {$icache_macro_count != 16 || $dcache_macro_count != 16} {
        error "postcompile cache SRAM split mismatch I=$icache_macro_count D=$dcache_macro_count"
    }

    set CURRENT_PHASE "POSTCOMPILE_CHECK_DESIGN"
    set check_ok 0
    redirect -tee -file "$RUN_DIR/reports/check_design_postcompile.rpt" { set check_ok [check_design] }
    if {!$check_ok} { error "postcompile check_design returned false" }

    write -format verilog -hierarchy -output "$RUN_DIR/outputs/rv64im_core_top_mapped.v"
    write -format ddc -hierarchy -output "$RUN_DIR/outputs/rv64im_core_top_mapped.ddc"
    write_sdc "$RUN_DIR/constraints/characterization_effective.sdc"
    redirect -file "$RUN_DIR/reports/report_qor.rpt" { report_qor }
    redirect -file "$RUN_DIR/reports/report_timing_max.rpt" { report_timing -delay_type max -path full -nets -transition_time -capacitance -slack_lesser_than 1000000.0 -max_paths 20 }
    redirect -file "$RUN_DIR/reports/report_area.rpt" { report_area -hierarchy }
    redirect -file "$RUN_DIR/reports/report_reference.rpt" { report_reference -hierarchy }
    redirect -file "$RUN_DIR/reports/report_cell.rpt" { report_cell }
    redirect -file "$RUN_DIR/reports/report_constraint_violators.rpt" { report_constraint -all_violators -verbose }
    redirect -file "$RUN_DIR/reports/check_timing_postcompile.rpt" { check_timing }
    redirect -file "$RUN_DIR/reports/report_clock_postcompile.rpt" { report_clock }

    set paths [get_timing_paths -delay_type max -max_paths 1]
    if {[sizeof_collection $paths] != 1} { error "no max timing path available" }
    set wns [get_attribute $paths slack]
    set sp [get_object_name [get_attribute $paths startpoint]]
    set ep [get_object_name [get_attribute $paths endpoint]]
    set pg [get_object_name [get_attribute $paths path_group]]
    set path_class [classify_path $sp $ep]
    set violating [get_timing_paths -delay_type max -slack_lesser_than 0.0 -max_paths 100000 -nworst 1]
    set violating_count [sizeof_collection $violating]
    set tns 0.0
    foreach_in_collection p $violating { set tns [expr {$tns + [get_attribute $p slack]}] }

    set leaf_cells [get_cells -hierarchical -quiet -filter "is_hierarchical == false"]
    set std_cells [remove_from_collection $leaf_cells $macro_cells]
    set stdcell_count [sizeof_collection $std_cells]
    set stdcell_area 0.0
    foreach_in_collection c $std_cells {
        set cell_area 0.0
        catch {set cell_area [get_attribute $c area]}
        if {$cell_area ne ""} { set stdcell_area [expr {$stdcell_area + $cell_area}] }
    }
    set macro_lib_cells [get_lib_cells -quiet */$SRAM_REF]
    if {[sizeof_collection $macro_lib_cells] != 1} { error "SRAM library cell not unique" }
    set macro_area [expr {$macro_count * [get_attribute $macro_lib_cells area]}]
    set total_area [expr {$stdcell_area + $macro_area}]

    status_append "UNRESOLVED_REFERENCE_COUNT=0"
    status_append "WNS_NS=$wns"
    status_append "TNS_NS=$tns"
    status_append "VIOLATING_PATH_COUNT=$violating_count"
    status_append "CRITICAL_PATH_STARTPOINT=$sp"
    status_append "CRITICAL_PATH_ENDPOINT=$ep"
    status_append "CRITICAL_PATH_GROUP=$pg"
    status_append "CRITICAL_PATH_CLASS=$path_class"
    status_append "STDCELL_INSTANCE_COUNT=$stdcell_count"
    status_append "SRAM_INSTANCE_COUNT=$macro_count"
    status_append "ICACHE_SRAM_INSTANCE_COUNT=$icache_macro_count"
    status_append "DCACHE_SRAM_INSTANCE_COUNT=$dcache_macro_count"
    status_append "CHECK_DESIGN_POSTCOMPILE_STATUS=PASS_WITH_POSSIBLE_NONBLOCKING_WARNINGS"
    status_append "TOTAL_DESIGN_AREA=$total_area"
    status_append "STDCELL_AREA=$stdcell_area"
    status_append "MACRO_AREA=$macro_area"
    status_append "MACRO_AREA_STATUS=AVAILABLE_FROM_LIBRARY_TIMING_MODEL"
    if {$wns >= 0.0 && $tns == 0.0} { status_append "DC_POINT_TIMING_STATUS=PASS" } else { status_append "DC_POINT_TIMING_STATUS=FAIL" }
    status_append "FLOW_STATUS=PASS"
}

set rc [catch {run_compile} message options]
if {$rc} {
    status_append "DC_COMPILE_ULTRA=FAIL"
    status_append "FLOW_STATUS=FAIL"
    status_append "FAILURE_PHASE=$CURRENT_PHASE"
    status_append "FIRST_FATAL_ERROR=$message"
    puts stderr "DC_SWEEP_POINT_FAIL phase=$CURRENT_PHASE detail=$message"
} else {
    puts "DC_SWEEP_POINT_FLOW=PASS"
}
quit
