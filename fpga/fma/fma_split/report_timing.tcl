# Description: This TCL script generates a detailed timing analysis report
#
# Pre-requisites: Design must already be compiled:
# $ quartus_sh.exe --flow compile ./fpga/fma/fma_split/fpga_top.qpf
#
# To run this script:
# $ cd <repo_root>
# $ quartus_sta.exe -t fpga/fma/fma_split/report_timing.tcl
#
# Note: Ensure that < Intel® Quartus® Prime directory>/quartus/bin directory is in your PATH environment variable
#
# Open project
project_open -force "./fpga/fma/fma_split/fpga_top.qpf" -revision "fpga_top"
# Netlist Setup
create_timing_netlist -model slow
read_sdc
update_timing_netlist
# Custom Report Timing
report_timing -from_clock { clk } -to_clock { clk } -setup -npaths 100 -detail full_path -panel_name {Report Timing} -file "./output_files/fpga_top.report_timing.rpt" -multi_corner
