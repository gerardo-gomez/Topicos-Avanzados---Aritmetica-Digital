// Descripcion: FSM controladora para orquestrar uso de FMA dot-product y lectura de ROMs, con contadores anidados de pasada, neurona y capa.

module control_fsm
    import neural_network_pkg::*;
(
    input  logic clk,
    input  logic rst,
    input  logic start,
    output logic done,

    output logic [WEIGHTS_ROM_ADDR_WIDTH-1:0] weights_rom_addr; // Direccion de lectura de la ROM de pesos
    output logic [BIASES_ROM_ADDR_WIDTH -1:0] biases_rom_addr;  // Direccion de lectura de la ROM de bias
);

  t_state state, state_nxt;

  logic [COUNTER_PASSES_WIDTH-1:0] counter_passes, counter_passes_nxt;
  logic [COUNTER_NEURON_WIDTH-1:0] counter_neuron, counter_neuron_nxt;
  logic [COUNTER_LAYER_WIDTH -1:0] counter_layer,  counter_layer_nxt;

  logic counter_passes_en, counter_neuron_en, counter_layer_en;
  logic counter_passes_rst, counter_neuron_rst, counter_layer_rst;

  /////////////////////////////////////////////////////////////
  // State transition logic
  /////////////////////////////////////////////////////////////

  always_comb begin
    if (rst) begin
      state_nxt = IDLE;
    end else begin
      state_nxt = state;
      unique case (state)
        IDLE:    state_nxt = start                                      ? LAYER_1 : IDLE;
        LAYER_1: state_nxt = (counter_layer == COUNTER_LAYER_WIDTH'(1)) ? LAYER_2 : LAYER_1;
        LAYER_2: state_nxt = (counter_layer == COUNTER_LAYER_WIDTH'(2)) ? DONE    : LAYER_2;
        DONE:    state_nxt = IDLE;
        default: state_nxt = IDLE;
      endcase
    end
  end

  /////////////////////////////////////////////////////////////
  // State output logic
  /////////////////////////////////////////////////////////////

  always_comb begin
    done               = 1'b0;
    counter_passes_en  = 1'b0;
    counter_neuron_en  = 1'b0;
    counter_layer_en   = 1'b0;
    counter_passes_rst = 1'b0;
    counter_neuron_rst = 1'b0;
    counter_layer_rst  = 1'b0;
    unique case (state)
      IDLE: begin
        counter_passes_rst = 1'b1;
        counter_neuron_rst = 1'b1;
        counter_layer_rst  = 1'b1;
      end
      LAYER_1: begin
        counter_passes_en  = 1'b1;
        counter_neuron_en  = counter_passes == COUNTER_PASSES_WIDTH'(NUM_LAYER_1_PASSES);
        counter_layer_en   = counter_neuron == COUNTER_NEURON_WIDTH'(NUM_HIDDEN_NEURONS);
        counter_passes_rst = counter_neuron_en | counter_layer_en;
      end
      LAYER_2: begin
        counter_passes_en  = 1'b1;
        counter_neuron_en  = counter_passes == COUNTER_PASSES_WIDTH'(NUM_LAYER_2_PASSES);
        counter_layer_en   = counter_neuron == COUNTER_NEURON_WIDTH'(NUM_HIDDEN_NEURONS + NUM_OUTPUT_NEURONS);
        counter_passes_rst = counter_neuron_en | counter_layer_en;
      end
      DONE: begin
        done = 1'b1;
      end
      default: begin
        done               = 1'b0;
        counter_passes_en  = 1'b0;
        counter_neuron_en  = 1'b0;
        counter_layer_en   = 1'b0;
        counter_passes_rst = 1'b0;
        counter_neuron_rst = 1'b0;
        counter_layer_rst  = 1'b0;
      end
    endcase
  end

  /////////////////////////////////////////////////////////////
  // ROM addresses generation
  /////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////
  // Counters
  /////////////////////////////////////////////////////////////

  always_comb begin
    if (rst | counter_passes_rst) begin
      counter_passes_nxt = '0;
    end else if (counter_passes_en) begin
      counter_passes_nxt = counter_passes + 1'b1;
    end else begin
      counter_passes_nxt = counter_passes;
    end
  end

  always_comb begin
    if (rst | counter_neuron_rst) begin
      counter_neuron_nxt = '0;
    end else if (counter_neuron_en) begin
      counter_neuron_nxt = counter_neuron + 1'b1;
    end else begin
      counter_neuron_nxt = counter_neuron;
    end
  end

  always_comb begin
    if (rst | counter_layer_rst) begin
      counter_layer_nxt = '0;
    end else if (counter_layer_en) begin
      counter_layer_nxt = counter_layer + 1'b1;
    end else begin
      counter_layer_nxt = counter_layer;
    end
  end

  /////////////////////////////////////////////////////////////
  // Flops
  /////////////////////////////////////////////////////////////

  always_ff @(posedge clk) begin
    state          <= state_nxt;
    counter_passes <= counter_passes_nxt;
    counter_neuron <= counter_neuron_nxt;
    counter_layer  <= counter_layer_nxt;
  end

endmodule
