# =============================================================================
# synth_with_mem.tcl
# Cadence Genus 21.14 - RV32IM Full Synthesis with Inferred Block RAM
# Library: GPDK045 LVT slow corner
# Target: Prove synthesizability + get area/timing/power reports
# Difference from synth_final.tcl:
#   - i_mem.sv and d_mem.sv are synthesis versions (no $readmemh)
#   - rv32im_top.sv is synthesis version (i_mem has clk/rst ports)
# =============================================================================

# Library
set_db init_lib_search_path /home/install/FOUNDRY/lan/flow/t1u1/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045_lvt/timing/
set_db library slow_vdd1v2_basicCells_lvt.lib

# Vicuna packages and interfaces (order matters)
read_hdl -sv vproc_pkg.sv
read_hdl -sv vproc_config.sv
read_hdl -sv vproc_xif.sv

# Scalar core supporting modules
read_hdl -sv my_pkg.sv
read_hdl -sv adder.sv
read_hdl -sv alu.sv
read_hdl -sv barrel_shifter.sv
read_hdl -sv mux2.sv
read_hdl -sv mux3.sv
read_hdl -sv mux4.sv
read_hdl -sv extend.sv
read_hdl -sv pc.sv
read_hdl -sv pc_src.sv
read_hdl -sv reg_file.sv
read_hdl -sv control_unit.sv
read_hdl -sv hazard_unit.sv
read_hdl -sv decode_reg.sv
read_hdl -sv execute_reg.sv
read_hdl -sv memory_reg.sv
read_hdl -sv writeback_reg.sv
read_hdl -sv load_unit.sv
read_hdl -sv store_unit.sv
read_hdl -sv multiplier_1c.sv
read_hdl -sv multiplier_16c.sv
read_hdl -sv divider_1c.sv
read_hdl -sv divider_32c.sv
read_hdl -sv btb.sv
read_hdl -sv pht.sv
read_hdl -sv gbh.sv
read_hdl -sv gshare.sv

# SYNTHESIS VERSION memories (no $readmemh)
read_hdl -sv i_mem_synth.sv
read_hdl -sv d_mem_synth.sv

# Vicuna RTL
read_hdl -sv vproc_vregfile.sv
read_hdl -sv vproc_vregpack.sv
read_hdl -sv vproc_vregunpack.sv
read_hdl -sv vproc_vreg_wr_mux.sv
read_hdl -sv vproc_pending_wr.sv
read_hdl -sv vproc_queue.sv
read_hdl -sv vproc_result.sv
read_hdl -sv vproc_alu.sv
read_hdl -sv vproc_mul_block.sv
read_hdl -sv vproc_mul.sv
read_hdl -sv vproc_sld.sv
read_hdl -sv vproc_elem.sv
read_hdl -sv vproc_lsu.sv
read_hdl -sv vproc_decoder.sv
read_hdl -sv vproc_dispatcher.sv
read_hdl -sv vproc_unit_mux.sv
read_hdl -sv vproc_unit_wrapper.sv
read_hdl -sv vproc_pipeline.sv
read_hdl -sv vproc_pipeline_wrapper.sv
read_hdl -sv vproc_top.sv
read_hdl -sv vproc_core.sv

# Wrapper and top - SYNTHESIS VERSION of rv32im_top
read_hdl -sv vicuna_wrapper.sv
read_hdl -sv rv32im.sv
read_hdl -sv rv32im_top_synth.sv

# Elaborate synthesis top
elaborate rv32im_top

# Clock constraint - 100MHz (10ns period)
create_clock -name clk -period 10 [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]

# Input/output delays
set_input_delay  2.0 -clock clk [all_inputs]
set_output_delay 2.0 -clock clk [all_outputs]

# Full synthesis flow
syn_gen -effort low
syn_map -effort low
syn_opt -effort low

# Reports
file mkdir reports_mem
report_area   -depth 3          > reports_mem/area.rpt
report_timing -nworst 5         > reports_mem/timing.rpt
report_power                    > reports_mem/power.rpt
report_gates                    > reports_mem/gates.rpt
report_messages                 > reports_mem/messages.rpt

puts "=== SYNTHESIS WITH MEMORY COMPLETE ==="
puts "Reports in reports_mem/"
