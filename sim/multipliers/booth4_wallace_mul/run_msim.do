# To run sim:
# $ cd <repo_root>
# $ vsim    -do ./sim/multipliers/booth4_wallace_mul/run_msim.do # To open Questa GUI and view waveforms.
# $ vsim -c -do ./sim/multipliers/booth4_wallace_mul/run_msim.do # To execute Questa CLI (-c) and check test status.

transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

# Supressed messages: Warning vopt-13314 - Defaulting port '' kind to 'var' rather than 'wire' due to default compile option setting of -svinputport=relaxed.

# Design files
vlog -sv -work work -suppress 13314 {./design/adders/fa.sv}
vlog -sv -work work -suppress 13314 {./design/adders/csa.sv}
vlog -sv -work work -suppress 13314 {./design/adders/wallace_tree.sv}
vlog -sv -work work -suppress 13314 {./design/adders/fa_gp.sv}
vlog -sv -work work -suppress 13314 {./design/adders/lcu4.sv}
vlog -sv -work work -suppress 13314 {./design/adders/cla.sv}
vlog -sv -work work -suppress 13314 {./design/multipliers/booth4_wallace_mul.sv}

# Testbench files
vlog -sv -work work -suppress 13314 {./verif/multipliers/tb_multiplier.sv}

vsim -t 1ps -L rtl_work -L work -voptargs="+acc" -suppress 13314 tb_multiplier

# Waveforms
view structure
view signals
do ./sim/multipliers/booth4_wallace_mul/wave.do

run -all
