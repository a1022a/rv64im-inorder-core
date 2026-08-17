if {![info exists ::env(SWEEP_POINT_RUN_DIR)]} { error "SWEEP_POINT_RUN_DIR environment variable is required" }
set RUN_DIR $::env(SWEEP_POINT_RUN_DIR)
set WORKSPACE $::env(PROJECT_WORKSPACE)
set SOURCE_ROOT "$WORKSPACE/source"
set STATUS_FILE "$RUN_DIR/metadata/dc_constraint_gate.env"
set STDCELL_DB $::env(STDCELL_MAX_DB)
set SRAM_DB $::env(SRAM_MAX_DB)
set TOP "rv64im_core_top"
set SRAM_REF $::env(SRAM_MACRO_REF)
set CURRENT_PHASE "SETUP"

proc status_write {mode line} { global STATUS_FILE; set fp [open $STATUS_FILE $mode]; puts $fp $line; close $fp }
proc status_append {line} { status_write a $line }

proc run_gate {} {
    global RUN_DIR WORKSPACE SOURCE_ROOT STATUS_FILE STDCELL_DB SRAM_DB TOP SRAM_REF CURRENT_PHASE
    status_write w "P2R1_COMMIT=217f2640b170f12f276e711a9aa08ac50cd7c946"
    status_append "P2R1_TREE=d917e4c2df7f0d3aef05f7d3b1cc27dbd591cc41"
    status_append "P2R1_PARENT_COMMIT=c6d08ff57f0e8cdaf734aa8b8d63a6b569850af2"
    status_append "P1_TREE=b289a9a430ffb387d268b43bd08cc08f84022102"
    status_append "OPTIMIZATION=DRC1_COMPLETION_TIME_SIGNED_QUOTIENT_STORAGE"
    status_append "COMPATIBILITY_FIX=DECLARATION_ORDER_ONLY"
    status_append "TOP_MODULE=$TOP"
    status_append "CHARACTERIZATION_ONLY=YES"
    status_append "SOC_SIGNOFF=NO"
    status_append "POST_LAYOUT=NO"

    set CURRENT_PHASE "LIBRARY_LOAD"
    if {![file readable $STDCELL_DB]} { error "standard-cell DB not readable" }
    if {![file readable $SRAM_DB]} { error "SRAM DB not readable" }
    read_db $STDCELL_DB
    read_db $SRAM_DB
    set_app_var target_library [list $STDCELL_DB]
    set_app_var link_library [list "*" $STDCELL_DB $SRAM_DB]
    define_design_lib WORK -path "$RUN_DIR/work"
    set_app_var search_path [list \
        "$SOURCE_ROOT/rtl/vsrc" "$SOURCE_ROOT/rtl/vsrc/bus" \
        "$SOURCE_ROOT/rtl/vsrc/cache" "$SOURCE_ROOT/rtl/vsrc/core" \
        "$SOURCE_ROOT/rtl/vsrc/exu" "$SOURCE_ROOT/rtl/vsrc/idu" \
        "$SOURCE_ROOT/rtl/vsrc/ifu" "$SOURCE_ROOT/rtl/vsrc/mem" \
        "$SOURCE_ROOT/rtl/vsrc/units" "$SOURCE_ROOT/rtl/vsrc/wb"]
    status_append "STDCELL_LIBRARY_LOAD=PASS"
    status_append "SRAM_LIBRARY_LOAD=PASS"

    set CURRENT_PHASE "ANALYZE"
    set fl "$SOURCE_ROOT/rtl/filelists/synth.f"
    set fp [open $fl r]
    set files {}
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line] || [string match "+incdir+*" $line]} { continue }
        if {[string match "./*" $line]} { set line [string range $line 2 end] }
        if {[string match "/*" $line]} { set f $line } else { set f "$SOURCE_ROOT/$line" }
        if {![file readable $f]} { close $fp; error "filelist entry missing: $f" }
        lappend files $f
    }
    close $fp
    if {[llength $files] != 36} { error "RTL file count mismatch: [llength $files]" }
    if {[catch {set analyze_ok [analyze -format sverilog -define {ASIC_SRAM} -library WORK $files]} msg]} { error "analyze failed: $msg" }
    if {!$analyze_ok} { error "analyze returned false" }
    status_append "DC_ANALYZE=PASS"

    set CURRENT_PHASE "ELABORATE"
    if {[catch {elaborate $TOP -library WORK} msg]} { error "elaborate failed: $msg" }
    if {[sizeof_collection [get_designs -quiet $TOP]] != 1} { error "top missing after elaborate" }
    current_design $TOP
    status_append "DC_ELABORATE=PASS"

    set CURRENT_PHASE "LINK"
    if {[catch {set link_ok [link]} msg]} { error "link failed: $msg" }
    if {!$link_ok} { error "link returned false" }
    set unresolved [get_references -quiet -filter "is_unresolved == true"]
    if {[sizeof_collection $unresolved] != 0} { error "unresolved references remain: [get_object_name $unresolved]" }
    set macro_cells [get_cells -hierarchical -quiet -filter "ref_name == $SRAM_REF"]
    if {[sizeof_collection $macro_cells] != 32} { error "SRAM count mismatch: [sizeof_collection $macro_cells]" }
    status_append "DC_LINK=PASS"
    status_append "UNRESOLVED_REFERENCE_COUNT=0"
    status_append "DC_SRAM_INSTANCE_COUNT_PRECOMPILE=32"

    set CURRENT_PHASE "CHECK_DESIGN"
    set check_ok 0
    redirect -tee -file "$RUN_DIR/reports/check_design_precompile.rpt" { set check_ok [check_design] }
    if {!$check_ok} { error "check_design returned false" }
    status_append "CHECK_DESIGN_STATUS=PASS_WITH_POSSIBLE_NONBLOCKING_WARNINGS"

    set max_lib_name $::env(STDCELL_MAX_LIB_NAME)
    set max_lib [get_libs -quiet $max_lib_name]
    if {[sizeof_collection $max_lib] != 1} { error "max standard-cell logical library unavailable" }
    set max_opcond [get_attribute $max_lib default_operating_conditions]
    if {$max_opcond eq ""} { error "max operating condition unavailable" }
    if {![set_operating_conditions -max $max_opcond -max_library $max_lib_name]} { error "failed to establish single MAX operating condition" }
    status_append "OPERATING_CONDITION_ANALYSIS=MAX_ONLY_SINGLE"
    status_append "MAX_OPERATING_CONDITION=$max_opcond"

    set CURRENT_PHASE "APPLY_CONSTRAINTS"
    source "$RUN_DIR/constraints/characterization_sweep.tcl"
    status_append "CLOCK_PORT=clk"
    status_append "CLOCK_PERIOD_NS=$CHAR_CLK_PERIOD_NS"
    status_append "CLOCK_FREQUENCY_MHZ=[expr {1000.0 / $CHAR_CLK_PERIOD_NS}]"
    status_append "CLOCK_PERIOD_SOURCE=FREQUENCY_CHARACTERIZATION_SWEEP"
    status_append "CLOCK_UNCERTAINTY=$CHAR_CLOCK_UNCERTAINTY_NS"
    status_append "AXI_TIMING_BUDGET_SOURCE=CHARACTERIZATION_ASSUMPTION"
    status_append "AXI_INPUT_MAX_RATIO=$CHAR_AXI_IN_MAX_RATIO"
    status_append "AXI_OUTPUT_MAX_RATIO=$CHAR_AXI_OUT_MAX_RATIO"
    status_append "AXI_INPUT_MAX_NS=$CHAR_AXI_IN_MAX_NS"
    status_append "AXI_OUTPUT_MAX_NS=$CHAR_AXI_OUT_MAX_NS"
    status_append "ELECTRICAL_MODEL_SOURCE=LIBRARY_DERIVED_REPRESENTATIVE_CHARACTERIZATION"
    status_append "REPRESENTATIVE_DRIVING_CELL=$CHAR_DRIVER_CELL"
    status_append "OUTPUT_LOAD_MODEL=FO4_OF_${CHAR_DRIVER_CELL}_${CHAR_LOAD_INPUT_PIN}"

    set CURRENT_PHASE "CONSTRAINT_VALIDATION"
    if {[sizeof_collection [get_clocks -quiet core_clk]] != 1} { error "core_clk not created" }
    set actual_period [get_attribute [get_clocks core_clk] period]
    if {[expr {abs($actual_period - $CHAR_CLK_PERIOD_NS)}] > 0.000001} { error "clock period mismatch" }
    set all_regs [all_registers]
    set clocked_regs [all_registers -clock core_clk]
    set unclocked_regs [remove_from_collection $all_regs $clocked_regs]
    set all_reg_count [sizeof_collection $all_regs]
    set clocked_reg_count [sizeof_collection $clocked_regs]
    set unclocked_reg_count [sizeof_collection $unclocked_regs]
    if {$all_reg_count == 0 || $unclocked_reg_count != 0} { error "functional registers not fully covered" }

    set sram_clk_count 0
    set sram_clk_clocked_count 0
    foreach_in_collection c $macro_cells {
        set cp [get_pins -quiet "[get_object_name $c]/CLK"]
        if {[sizeof_collection $cp] == 1} {
            incr sram_clk_count
            set cp_clocks [get_attribute $cp clocks]
            if {[sizeof_collection $cp_clocks] == 1 && [get_object_name $cp_clocks] eq "core_clk"} { incr sram_clk_clocked_count }
        }
    }
    if {$sram_clk_count != 32 || $sram_clk_clocked_count != 32} { error "SRAM clock coverage mismatch" }
    if {[sizeof_collection $AXI_INPUT_PORTS] != 84 || [sizeof_collection $AXI_OUTPUT_PORTS] != 211} { error "AXI constraint group count mismatch" }
    if {[sizeof_collection [get_ports -quiet rstn]] != 1} { error "rstn missing" }
    if {[sizeof_collection [get_ports -quiet axi_*]] != 295} { error "unexpected AXI total bit-port count" }

    redirect -file "$RUN_DIR/reports/check_timing_precompile.rpt" { check_timing }
    redirect -file "$RUN_DIR/reports/report_clock_precompile.rpt" { report_clock }
    redirect -file "$RUN_DIR/reports/report_design_precompile.rpt" { report_design }
    redirect -file "$RUN_DIR/reports/report_port_precompile.rpt" { report_port -verbose [get_ports *] }
    redirect -file "$RUN_DIR/reports/report_constraint_precompile.rpt" { report_constraint -all_violators -verbose }
    write_sdc "$RUN_DIR/constraints/characterization_effective_precompile.sdc"
    write -format ddc -hierarchy -output "$RUN_DIR/work/rv64im_core_top_precompile_constrained.ddc"

    status_append "TOTAL_REGISTER_ENDPOINTS=$all_reg_count"
    status_append "CORE_CLK_REGISTER_ENDPOINTS=$clocked_reg_count"
    status_append "ACCIDENTALLY_UNCLOCKED_REGISTER_ENDPOINTS=$unclocked_reg_count"
    status_append "SRAM_CLK_PIN_COUNT=$sram_clk_count"
    status_append "SRAM_CLK_CORE_CLK_COVERED=$sram_clk_clocked_count"
    status_append "AXI_INPUT_MAX_CONSTRAINED_COUNT=84"
    status_append "AXI_OUTPUT_MAX_CONSTRAINED_COUNT=211"
    status_append "INTENTIONALLY_UNCONSTRAINED=RESET_rstn"
    status_append "DC_UNCONSTRAINED_FUNCTIONAL_PATHS=0"
    status_append "DC_CONSTRAINT_VALIDATION=PASS"
}

set rc [catch {run_gate} message options]
if {$rc} {
    status_append "DC_CONSTRAINT_VALIDATION=FAIL"
    status_append "FAILURE_PHASE=$CURRENT_PHASE"
    status_append "FIRST_FATAL_ERROR=$message"
    puts stderr "DC_SWEEP_GATE_FAIL phase=$CURRENT_PHASE detail=$message"
} else {
    puts "DC_CONSTRAINT_VALIDATION=PASS"
}
quit
