# Legacy synthesis-intent scope for top rv64im_core_top.
# Excludes simulation top rv64im_core_sim_top, DPI-only logic, C/C++, testbench code,
# generated files, and backup files.
#
# RAM synthesis strategy is TBD. S011HD1P_X32Y2D128_BW.sv is listed only as the
# current unresolved memory dependency of rv64im_core_ram, not as an approved formal
# synthesis memory policy.
./rtl/vsrc/rv64im_core_defines.sv
./rtl/vsrc/bus/rv64im_core_1toN.sv
./rtl/vsrc/bus/rv64im_core_2to1.sv
./rtl/vsrc/bus/rv64im_core_AtoB.sv
./rtl/vsrc/bus/rv64im_core_axi.sv
./rtl/vsrc/bus/rv64im_core_clint.sv
./rtl/vsrc/bus/rv64im_core_Nto1.sv
./rtl/vsrc/cache/rv64im_core_dcache.sv
./rtl/vsrc/cache/rv64im_core_ram.sv
./rtl/vsrc/core/rv64im_core_core.sv
./rtl/vsrc/core/rv64im_core_pipe_ctrl.sv
./rtl/vsrc/exu/rv64im_core_alu.sv
./rtl/vsrc/exu/rv64im_core_booth_mul.sv
./rtl/vsrc/exu/rv64im_core_csr_reg.sv
./rtl/vsrc/exu/rv64im_core_div.sv
./rtl/vsrc/exu/rv64im_core_exu.sv
./rtl/vsrc/exu/rv64im_core_id_alu.sv
./rtl/vsrc/exu/rv64im_core_intr_ctrl.sv
./rtl/vsrc/idu/rv64im_core_id.sv
./rtl/vsrc/idu/rv64im_core_idu.sv
./rtl/vsrc/idu/rv64im_core_if_id.sv
./rtl/vsrc/idu/rv64im_core_regfile.sv
./rtl/vsrc/ifu/rv64im_core_ifu.sv
./rtl/vsrc/ifu/rv64im_core_ras.sv
./rtl/vsrc/ifu/rv64im_core_satcnt.sv
./rtl/vsrc/mem/rv64im_core_ls.sv
./rtl/vsrc/mem/rv64im_core_lsu.sv
./rtl/vsrc/units/S011HD1P_X32Y2D128_BW.sv
./rtl/vsrc/units/rv64im_core_add4to2.sv
./rtl/vsrc/units/rv64im_core_add_full.sv
./rtl/vsrc/units/rv64im_core_cla4.sv
./rtl/vsrc/units/rv64im_core_compress_34to2.sv
./rtl/vsrc/units/rv64im_core_reg.sv
./rtl/vsrc/wb/rv64im_core_wb.sv
./rtl/vsrc/wb/rv64im_core_wbu.sv
./rtl/vsrc/rv64im_core_top.sv
