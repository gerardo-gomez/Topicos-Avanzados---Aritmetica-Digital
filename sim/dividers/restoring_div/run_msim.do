# To run sim:
# $ cd <repo_root>
# $ vsim    -do ./sim/dividers/restoring_div/run_msim.do # To open Questa GUI and view waveforms.
# $ vsim -c -do ./sim/dividers/restoring_div/run_msim.do # To execute Questa CLI (-c) and check test status.

transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

# Supressed messages:
# - Warning vopt-13314 - Defaulting port '' kind to 'var' rather than 'wire' due to default compile option setting of -svinputport=relaxed.
# - Error (suppressible): (vopt-14408) Altera Starter FPGA Edition recommended capacity is 5000 non-OEM instances. There are 6170 non OEM instances. Expect performance to be severely impacted.
# - Error (suppressible): (vsim-16154) Design size exceeds Questa Altera Starter FPGA Edition recommended capacity limit of 5000. Expect performance to be severely impacted.

# Design files
vlog -sv -work work -suppress 13314 -suppress 14408 -suppress 16154 {./design/adders/fa_gp.sv}
vlog -sv -work work -suppress 13314 -suppress 14408 -suppress 16154 {./design/adders/lcu4.sv}
vlog -sv -work work -suppress 13314 -suppress 14408 -suppress 16154 {./design/adders/cla.sv}
vlog -sv -work work -suppress 13314 -suppress 14408 -suppress 16154 {./design/dividers/restoring_div.sv}

# Testbench files
vlog -sv -work work -suppress 13314 -suppress 14408 -suppress 16154 {./verif/dividers/tb_divider.sv}

vsim -t 1ps -L rtl_work -L work -voptargs="+acc" -suppress 13314 -suppress 14408 -suppress 16154 tb_divider

# Waveforms
#view structure
#view signals
#do ./sim/dividers/restoring_div/wave.do

run -all
