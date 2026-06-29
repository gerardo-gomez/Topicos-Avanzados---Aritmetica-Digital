# To run sim:
# $ cd <repo_root>
# $ vsim    -do ./sim/adders/rca/run_msim.do # To open Questa GUI and view waveforms.
# $ vsim -c -do ./sim/adders/rca/run_msim.do # To execute Questa CLI (-c) and check test status.

transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

# Supressed messages: Warning vopt-13314 - Defaulting port '' kind to 'var' rather than 'wire' due to default compile option setting of -svinputport=relaxed.

# Design files
vlog -sv -work work -suppress 13314 {./design/adders/fa.sv}
vlog -sv -work work -suppress 13314 {./design/adders/rca.sv}

# Testbench files
vlog -sv -work work -suppress 13314 {./verif/adders/tb_rca.sv}

vsim -t 1ps -L rtl_work -L work -voptargs="+acc" -suppress 13314 tb_adder

# Waveforms
#view structure
#view signals
#do ./sim/adders/rca/wave.do

run -all
