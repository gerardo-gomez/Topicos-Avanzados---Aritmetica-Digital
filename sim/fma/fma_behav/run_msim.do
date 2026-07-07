# To run sim:
# $ cd <repo_root>
# $ vsim    -do ./sim/fma/fma_behav/run_msim.do # To open Questa GUI and view waveforms.
# $ vsim -c -do ./sim/fma/fma_behav/run_msim.do # To execute Questa CLI (-c) and check test status.

transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

# Supressed messages: Warning vopt-13314 - Defaulting port '' kind to 'var' rather than 'wire' due to default compile option setting of -svinputport=relaxed.

# Design files
vlog -sv -work work -suppress 13314 {./design/fma/fma_behav.sv}

# Testbench files
vlog -sv -work work -suppress 13314 {./verif/fma/tb_fma.sv}

vsim -t 1ps -L rtl_work -L work -voptargs="+acc" -suppress 13314 tb_fma

# Waveforms
#view structure
#view signals
#do ./sim/fma/fma_behav/wave.do

run -all
