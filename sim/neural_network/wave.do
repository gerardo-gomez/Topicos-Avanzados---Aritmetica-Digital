onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /neural_network_digits_tb/dut/clk
add wave -noupdate /neural_network_digits_tb/dut/rst
add wave -noupdate /neural_network_digits_tb/dut/start
add wave -noupdate /neural_network_digits_tb/dut/image
add wave -noupdate /neural_network_digits_tb/dut/done
add wave -noupdate /neural_network_digits_tb/dut/digit
add wave -noupdate /neural_network_digits_tb/dut/acc
add wave -noupdate /neural_network_digits_tb/dut/hidden_act
add wave -noupdate /neural_network_digits_tb/dut/is_higher_score
add wave -noupdate /neural_network_digits_tb/dut/argmax
add wave -noupdate /neural_network_digits_tb/dut/predicted_digit
add wave -noupdate /neural_network_digits_tb/dut/weights
add wave -noupdate /neural_network_digits_tb/dut/bias
add wave -noupdate /neural_network_digits_tb/dut/weights_rom_addr
add wave -noupdate /neural_network_digits_tb/dut/biases_rom_addr
add wave -noupdate /neural_network_digits_tb/dut/fma_dp_srca
add wave -noupdate /neural_network_digits_tb/dut/fma_dp_srcb
add wave -noupdate /neural_network_digits_tb/dut/fma_dp_srcc
add wave -noupdate /neural_network_digits_tb/dut/fma_dp_result
add wave -noupdate /neural_network_digits_tb/dut/pixels_group
add wave -noupdate /neural_network_digits_tb/dut/hidden_acts_group
add wave -noupdate /neural_network_digits_tb/dut/sel_pixels_group
add wave -noupdate /neural_network_digits_tb/dut/sel_hidden_neurons_group
add wave -noupdate /neural_network_digits_tb/dut/sel_hidden_neuron
add wave -noupdate /neural_network_digits_tb/dut/sel_output_neuron
add wave -noupdate /neural_network_digits_tb/dut/is_layer_1
add wave -noupdate /neural_network_digits_tb/dut/is_pass_0
add wave -noupdate /neural_network_digits_tb/dut/acc_en
add wave -noupdate /neural_network_digits_tb/dut/acc_rst
add wave -noupdate /neural_network_digits_tb/dut/hidden_neuron_en
add wave -noupdate /neural_network_digits_tb/dut/output_neuron_en
add wave -noupdate /neural_network_digits_tb/dut/neuron_rst
add wave -noupdate /neural_network_digits_tb/dut/predicted_digit_nxt
add wave -noupdate /neural_network_digits_tb/dut/predicted_digit
add wave -noupdate -divider FSM
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/state
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_passes
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_neurons
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_weights
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_neurons_en
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_weights_en
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_neurons_rst
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_weights_rst
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_passes_is_zero
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_passes_layer_2_done
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_passes_layer_1_done
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_neurons_layer_2_done
add wave -noupdate /neural_network_digits_tb/dut/control_fsm/counter_neurons_layer_1_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {12170000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 333
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
configure wave -timelineunits ns
update
WaveRestoreZoom {12014089 ps} {12325911 ps}
