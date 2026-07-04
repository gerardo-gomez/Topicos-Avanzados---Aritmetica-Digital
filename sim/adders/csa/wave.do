onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_csa/clk
add wave -noupdate /tb_csa/dut/tree_in
add wave -noupdate /tb_csa/dut/tree_out
add wave -noupdate /tb_csa/result
add wave -noupdate -divider Internal
add wave -noupdate /tb_csa/dut/wallace_tree/csa_in
add wave -noupdate /tb_csa/dut/wallace_tree/csa_out
add wave -noupdate /tb_csa/dut/wallace_tree/lvl_input_operands
add wave -noupdate /tb_csa/dut/wallace_tree/lvl_output_operands
add wave -noupdate /tb_csa/dut/wallace_tree/NUM_CSA_LEVELS
add wave -noupdate /tb_csa/dut/wallace_tree/NUM_IN
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {5401 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 309
configure wave -valuecolwidth 147
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {5072 ps} {5730 ps}
