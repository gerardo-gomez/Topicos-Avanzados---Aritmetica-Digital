onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_adder/clk
add wave -noupdate /tb_adder/dut/srca
add wave -noupdate /tb_adder/dut/srcb
add wave -noupdate /tb_adder/dut/cin
add wave -noupdate /tb_adder/dut/cout
add wave -noupdate /tb_adder/dut/result
add wave -noupdate -divider FA
add wave -noupdate /tb_adder/dut/fa_cin
add wave -noupdate /tb_adder/dut/fa_g
add wave -noupdate /tb_adder/dut/fa_p
add wave -noupdate /tb_adder/dut/lcu_cin
add wave -noupdate /tb_adder/dut/lcu_g
add wave -noupdate /tb_adder/dut/lcu_p
add wave -noupdate /tb_adder/dut/lcu_c
add wave -noupdate /tb_adder/dut/lcu_gg
add wave -noupdate /tb_adder/dut/lcu_pg
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {17225 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
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
configure wave -timelineunits ps
update
WaveRestoreZoom {10832 ps} {21332 ps}
