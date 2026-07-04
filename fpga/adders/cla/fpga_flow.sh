# Description: This script compiles the design in Quartus and generates a detailed timing analysis report
#
# To run this script:
# cd <repo_root>
# $ source ./fpga/adders/cla/fpga_flow.sh
#
# Note: Ensure that < Intel® Quartus® Prime directory>/quartus/bin directory is in your PATH environment variable
#
# Run compilation and generates timing analysis reports
quartus_sh.exe --flow compile ./fpga/adders/cla/fpga_top.qpf
# Reports detailed timing of the first 100 paths
quartus_sta.exe -t ./fpga/adders/cla/report_timing.tcl
