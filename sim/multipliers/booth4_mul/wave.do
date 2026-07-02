onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_multiplier/clk
add wave -noupdate /tb_multiplier/srca
add wave -noupdate /tb_multiplier/srcb
add wave -noupdate /tb_multiplier/is_signed
add wave -noupdate /tb_multiplier/result
add wave -noupdate /tb_multiplier/dut/srca_comp2
add wave -noupdate -expand -subitemconfig {{/tb_multiplier/dut/booth_triplet[1]} -expand {/tb_multiplier/dut/booth_triplet[0]} -expand} /tb_multiplier/dut/booth_triplet
add wave -noupdate /tb_multiplier/dut/booth_pp
add wave -noupdate /tb_multiplier/dut/booth_pp_sign
add wave -noupdate /tb_multiplier/dut/booth_pp_shifted
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {7418 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 211
configure wave -valuecolwidth 110
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
WaveRestoreZoom {4793 ps} {10043 ps}
