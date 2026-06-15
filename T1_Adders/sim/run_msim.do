# To run sim:
# $ vsim    -do ./sim/run_msim.do # To open Questa GUI and view waveforms. Make sure to uncomment "view structure", "view signals" and "do wave.do" commands from run_msim.do
# $ vsim -c -do ./sim/run_msim.do # To execute Questa CLI (-c). Make sure to comment out "view structure", "view signals" and "do wave.do" commands from run_msim.do

transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

# Supressed messages: Warning vopt-13314 - Defaulting port '' kind to 'var' rather than 'wire' due to default compile option setting of -svinputport=relaxed.

# Design files
# Ripple Carry Adder files
#vlog -sv -work work -suppress 13314 {./design/fa.sv}
#vlog -sv -work work -suppress 13314 {./design/rca.sv}
# Carry Look-Ahead Adder files
vlog -sv -work work -suppress 13314 {./design/cla4.sv}
vlog -sv -work work -suppress 13314 {./design/cla.sv}

# Testbench files
vlog -sv -work work -suppress 13314 {./verif/tb_adder.sv}

vsim -t 1ps -L rtl_work -L work -voptargs="+acc" -suppress 13314 tb_adder

# Waveforms
#view structure
#view signals
#do wave.do

run -all
