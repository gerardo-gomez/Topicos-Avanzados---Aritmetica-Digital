// Descripcion: FSM controladora para orquestrar uso de FMA dot-product y lectura de ROMs, con contadores anidados de pasada, neurona y capa.

module control_fsm
    import neural_network_pkg::*;
(
    input logic clk,
    input logic rst,

    // Inicio y fin de procesamiento de la red neuronal
    input  logic start,
    output logic done,

    // Selectores
    output t_pixels_group_idx         sel_pixels_group,         // Selector de grupo de pixeles (3 bits para 8 grupos)
    output t_hidden_neurons_group_idx sel_hidden_neurons_group, // Selector de grupo de neuronas ocultas (1 bit para 2 grupos)
    output t_hidden_neuron_idx        sel_hidden_neuron,        // Selector de neurona oculta (4 bits para 16 neuronas)
    output t_output_neuron_idx        sel_output_neuron,        // Selector de neurona de salida (4 bits para 10 neuronas)
    output logic                      is_layer_1,
    output logic                      is_pass_0,

    // Write enables y resets de neuronas y acumulador
    output logic acc_en,
    output logic acc_rst,
    output logic hidden_neuron_en,
    output logic output_neuron_en,
    output logic neuron_rst,

    // Direcciones de lectura de ROMs
    output logic [WEIGHTS_ROM_ADDR_WIDTH-1:0] weights_rom_addr, // Direccion de lectura de la ROM de pesos
    output logic [BIASES_ROM_ADDR_WIDTH -1:0] biases_rom_addr   // Direccion de lectura de la ROM de bias
);

  t_state state, state_nxt;

  logic [COUNTER_PASSES_WIDTH -1:0] counter_passes,  counter_passes_nxt;
  logic [COUNTER_NEURONS_WIDTH-1:0] counter_neurons, counter_neurons_nxt;
  logic [COUNTER_WEIGHTS_WIDTH-1:0] counter_weights, counter_weights_nxt;

  logic counter_passes_en,  counter_neurons_en,  counter_weights_en;
  logic counter_passes_rst, counter_neurons_rst, counter_weights_rst;

  logic counter_passes_is_zero;
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
    done                     = 1'b0;
    counter_weights_en       = 1'b0;
    counter_weights_rst      = 1'b0;
    counter_passes_en        = 1'b0;
    counter_passes_rst       = 1'b0;
    counter_neurons_en       = 1'b0;
    counter_neurons_rst      = 1'b0;
    sel_pixels_group         = '0;
    sel_hidden_neurons_group = '0;
    sel_hidden_neuron        = '0;
    sel_output_neuron        = '0;
    is_layer_1               = 1'b0;
    is_pass_0                = 1'b0;
    acc_en                   = 1'b0;
    acc_rst                  = 1'b0;
    hidden_neuron_en         = 1'b0;
    output_neuron_en         = 1'b0;
    neuron_rst               = 1'b0;
    unique case (state)
      IDLE: begin
        counter_weights_rst = start;
        counter_passes_rst  = start;
        counter_neurons_rst = start;
        acc_rst             = start;
        neuron_rst          = start;
      end
      LAYER_1: begin
        counter_weights_en = 1'b1;
        counter_passes_en  = 1'b1;
        counter_passes_rst = counter_passes_layer_1_done;
        counter_neurons_en = counter_passes_layer_1_done;

        is_pass_0         = counter_passes_is_zero;
        is_layer_1        = 1'b1;
        sel_pixels_group  = t_pixels_group_idx'(counter_passes);
        sel_hidden_neuron = t_hidden_neuron_idx'(counter_neurons);

        hidden_neuron_en = counter_passes_layer_1_done;
        acc_rst          = counter_passes_layer_1_done;
        acc_en           = 1'b1;
      end
      LAYER_2: begin
        counter_weights_en = 1'b1;
        counter_passes_en  = 1'b1;
        counter_passes_rst = counter_passes_layer_2_done;
        counter_neurons_en = counter_passes_layer_2_done;

        is_pass_0                = counter_passes_is_zero;
        sel_hidden_neurons_group = t_hidden_neurons_group_idx'(counter_passes);
        sel_output_neuron        = f_convert_global_to_output_neuron_idx(t_global_neuron_idx'(counter_neurons));

        output_neuron_en = counter_passes_layer_2_done;
        acc_rst          = counter_passes_layer_2_done;
        acc_en           = 1'b1;
      end
      DONE: begin
        done = 1'b1;
      end
      default: begin
        done                     = 1'b0;
        counter_weights_en       = 1'b0;
        counter_weights_rst      = 1'b0;
        counter_passes_en        = 1'b0;
        counter_passes_rst       = 1'b0;
        counter_neurons_en       = 1'b0;
        counter_neurons_rst      = 1'b0;
        sel_pixels_group         = '0;
        sel_hidden_neurons_group = '0;
        sel_hidden_neuron        = '0;
        sel_output_neuron        = '0;
        is_layer_1               = 1'b0;
        is_pass_0                = 1'b0;
        acc_en                   = 1'b0;
        acc_rst                  = 1'b0;
        hidden_neuron_en         = 1'b0;
        output_neuron_en         = 1'b0;
        neuron_rst               = 1'b0;
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
  assign counter_passes_is_zero      = ~(|counter_passes);

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
