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

  logic [COUNTER_PASSES_WIDTH -1:0] counter_passes,  counter_passes_nxt;
  logic [COUNTER_NEURONS_WIDTH-1:0] counter_neurons, counter_neurons_nxt;
  logic [COUNTER_WEIGHTS_WIDTH-1:0] counter_weights, counter_weights_nxt;

  logic counter_passes_en,  counter_neurons_en,  counter_weights_en;
  logic counter_passes_rst, counter_neurons_rst, counter_weights_rst;

  logic counter_passes_layer_1_done,  counter_passes_layer_2_done;
  logic counter_neurons_layer_1_done, counter_neurons_layer_2_done;

  /////////////////////////////////////////////////////////////
  // State transition logic
  /////////////////////////////////////////////////////////////

  always_comb begin
    if (rst) begin
      state_nxt = IDLE;
    end else begin
      state_nxt = state;
      unique case (state)
        IDLE:    state_nxt =  start                                                       ? LAYER_1 : IDLE;
        LAYER_1: state_nxt = (counter_passes_layer_1_done & counter_neurons_layer_1_done) ? LAYER_2 : LAYER_1;
        LAYER_2: state_nxt = (counter_passes_layer_2_done & counter_neurons_layer_2_done) ? DONE    : LAYER_2;
        DONE:    state_nxt = IDLE;
        default: state_nxt = IDLE;
      endcase
    end
  end

  /////////////////////////////////////////////////////////////
  // State output logic
  /////////////////////////////////////////////////////////////

  always_comb begin
    done                = 1'b0;
    counter_weights_en  = 1'b0;
    counter_weights_rst = 1'b0;
    counter_passes_en   = 1'b0;
    counter_passes_rst  = 1'b0;
    counter_neurons_en  = 1'b0;
    counter_neurons_rst = 1'b0;
    unique case (state)
      IDLE: begin
        counter_weights_rst = 1'b1;
        counter_passes_rst  = 1'b1;
        counter_neurons_rst = 1'b1;
      end
      LAYER_1: begin
        counter_weights_en = 1'b1;
        counter_passes_en  = 1'b1;
        counter_passes_rst = counter_passes_layer_1_done;
        counter_neurons_en = counter_passes_layer_1_done;
      end
      LAYER_2: begin
        counter_weights_en = 1'b1;
        counter_passes_en  = 1'b1;
        counter_passes_rst = counter_passes_layer_2_done;
        counter_neurons_en = counter_passes_layer_2_done;
      end
      DONE: begin
        done = 1'b1;
      end
      default: begin
        done                = 1'b0;
        counter_weights_en  = 1'b0;
        counter_weights_rst = 1'b0;
        counter_passes_en   = 1'b0;
        counter_passes_rst  = 1'b0;
        counter_neurons_en  = 1'b0;
        counter_neurons_rst = 1'b0;
      end
    endcase
  end

  /////////////////////////////////////////////////////////////
  // ROM addresses generation
  /////////////////////////////////////////////////////////////

  assign weights_rom_addr = counter_weights;
  assign biases_rom_addr  = counter_neurons;

  /////////////////////////////////////////////////////////////
  // Counters
  /////////////////////////////////////////////////////////////

  always_comb begin
    if (rst | counter_weights_rst) begin
      counter_weights_nxt = '0;
    end else if (counter_weights_en) begin
      counter_weights_nxt = counter_weights + 1'b1;
    end else begin
      counter_weights_nxt = counter_weights;
    end
  end

  always_comb begin
    if (rst | counter_passes_rst) begin
      counter_passes_nxt = '0;
    end else if (counter_passes_en) begin
      counter_passes_nxt = counter_passes + 1'b1;
    end else begin
      counter_passes_nxt = counter_passes;
    end
  end

  assign counter_passes_layer_1_done = counter_passes == (NUM_LAYER_1_PASSES - 1);
  assign counter_passes_layer_2_done = counter_passes == (NUM_LAYER_2_PASSES - 1);

  always_comb begin
    if (rst | counter_neurons_rst) begin
      counter_neurons_nxt = '0;
    end else if (counter_neurons_en) begin
      counter_neurons_nxt = counter_neurons + 1'b1;
    end else begin
      counter_neurons_nxt = counter_neurons;
    end
  end

  assign counter_neurons_layer_1_done = counter_neurons == (NUM_HIDDEN_NEURONS - 1);
  assign counter_neurons_layer_2_done = counter_neurons == (NUM_TOTAL_NEURONS  - 1);

  /////////////////////////////////////////////////////////////
  // Flops
  /////////////////////////////////////////////////////////////

  always_ff @(posedge clk) begin
    state           <= state_nxt;
    counter_passes  <= counter_passes_nxt;
    counter_neurons <= counter_neurons_nxt;
  end

endmodule
