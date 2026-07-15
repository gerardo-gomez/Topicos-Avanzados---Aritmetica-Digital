# To run sim:
# $ cd <repo_root>
# $ vsim    -do ./sim/floating_point/fp_add/run_msim.do # To open Questa GUI and view waveforms.
# $ vsim -c -do ./sim/floating_point/fp_add/run_msim.do # To execute Questa CLI (-c) and check test status.

transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

# Supressed messages: Warning vopt-13314 - Defaulting port '' kind to 'var' rather than 'wire' due to default compile option setting of -svinputport=relaxed.

# Design files
vlog -sv -work work -suppress 13314 {./design/floating_point/fp_add.sv}

# Testbench files
vlog -sv -work work -suppress 13314 {./verif/floating_point/tb_fp_adder.sv}

vsim -t 1ps -L rtl_work -L work -voptargs="+acc" -suppress 13314 tb_fp_adder

# Waveforms
#view structure
#view signals
#do ./sim/floating_point/fp_add/wave.do

run -all
