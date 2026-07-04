# Description: This script compiles the design in Quartus and generates a detailed timing analysis report
#
# To run this script:
# cd <repo_root>
# $ source ./fpga/multipliers/array_wallace_mul/generate_reports.sh
#
# Note: Ensure that < Intel® Quartus® Prime directory>/quartus/bin directory is in your PATH environment variable
#
# Run compilation and generates timing analysis reports
quartus_sh.exe --flow compile ./fpga/multipliers/array_wallace_mul/fpga_top.qpf
# Reports detailed timing of the first 100 paths
quartus_sta.exe -t ./fpga/multipliers/array_wallace_mul/report_timing.tcl
