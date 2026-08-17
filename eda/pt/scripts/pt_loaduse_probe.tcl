set RUN_DIR $::env(PT_RUN_DIR)
set DC_RUN_DIR $::env(DC_POINT_RUN_DIR)
set STDCELL_DB $::env(STDCELL_MAX_DB)
set SRAM_DB $::env(SRAM_MAX_DB)
set NETLIST "$DC_RUN_DIR/outputs/rv64im_core_top_mapped.v"
set SDC "$DC_RUN_DIR/constraints/characterization_effective.sdc"
set TOP rv64im_core_top
set SRAM_REF $::env(SRAM_MACRO_REF)
set STATUS_FILE "$RUN_DIR/metadata/pt_loaduse_probe.env"

proc emit {line} {
    global STATUS_FILE
    set fp [open $STATUS_FILE a]
    puts $fp $line
    close $fp
}

file delete -force $STATUS_FILE
set_app_var search_path [list [file dirname $NETLIST]]
set_app_var link_path [list "*" $STDCELL_DB $SRAM_DB]
read_verilog $NETLIST
current_design $TOP
if {![link_design $TOP]} { error "link failed" }
read_sdc $SDC

set dcache_sram [get_cells -hierarchical -quiet -filter "ref_name == $SRAM_REF && full_name =~ *u_rv64im_core_dcache*"]
set dcache_q [get_pins -quiet -of_objects $dcache_sram -filter "direction == out"]
set id_alu_regs [get_cells -hierarchical -quiet -filter "is_sequential == true && full_name =~ *u_rv64im_core_id_alu*"]
set probe_paths [get_timing_paths -delay_type max -from $dcache_q -to $id_alu_regs -slack_lesser_than 1000000.0 -max_paths 20 -nworst 1]

emit "P2R1_COMMIT=217f2640b170f12f276e711a9aa08ac50cd7c946"
emit "P2R1_TREE=d917e4c2df7f0d3aef05f7d3b1cc27dbd591cc41"
emit "P2R1_PARENT_COMMIT=c6d08ff57f0e8cdaf734aa8b8d63a6b569850af2"
emit "DCACHE_SRAM_INSTANCE_COUNT=[sizeof_collection $dcache_sram]"
emit "DCACHE_SRAM_OUTPUT_PIN_COUNT=[sizeof_collection $dcache_q]"
emit "ID_ALU_REGISTER_COUNT=[sizeof_collection $id_alu_regs]"
emit "LOADUSE_PROBE_PATH_COUNT=[sizeof_collection $probe_paths]"

if {[sizeof_collection $probe_paths] > 0} {
    set worst [index_collection $probe_paths 0]
    emit "LOADUSE_PROBE_WNS_NS=[get_attribute $worst slack]"
    emit "LOADUSE_PROBE_STARTPOINT=[get_object_name [get_attribute $worst startpoint]]"
    emit "LOADUSE_PROBE_ENDPOINT=[get_object_name [get_attribute $worst endpoint]]"
    redirect -file "$RUN_DIR/reports/report_timing_loaduse_probe.rpt" {
        report_timing -delay_type max -from $dcache_q -to $id_alu_regs -path_type full -input_pins -nets -transition_time -capacitance -slack_lesser_than 1000000.0 -max_paths 20 -nworst 1
    }
    emit "LOADUSE_PROBE_STATUS=PASS"
} else {
    emit "LOADUSE_PROBE_STATUS=NO_PATH_FOUND"
}
quit
