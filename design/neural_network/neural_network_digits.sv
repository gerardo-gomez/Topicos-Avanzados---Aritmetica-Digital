// Descripcion: Clasificador de digitos con red neuronal sobre un FMA tipo producto punto (FMA dot-product)
//              Ver descripcion de proyecto para detalles de la arquitectura de la red y cuantizacion
//
// Diagrama de tiempos para procesar una imagen
// Ciclo     Acción
// 0         el TB pone image con la k-ésima imagen
// 1         el TB levanta start durante un ciclo
// 2 ...T-1  el DUT procesa; done = 0
// T         el DUT levanta done durante un ciclo; digit válido
// T+1       el TB registra el resultado y prepara la imagen k+1

module neural_network_digits
    import neural_network_pkg::*;
(
    input  logic                         clk,
    input  logic                         rst,                               // Reset activo en alto.
    input  logic                         start,                             // Pulso de un ciclo que indica que hay un nuevo dígito a procesar.
                                                                            // El módulo comienza el cómputo en el flanco siguiente y no vuelve a mirar start hasta terminar.
    input  logic [IMAGE_PIXEL_WIDTH-1:0] image [IMAGE_HORIZONTAL_SIZE-1:0]  // Digito representado como una matriz 8x8 de pixeles uint4.
                                               [IMAGE_VERTICAL_SIZE  -1:0], // Debe estar estable antes del pulso de start y puede cambiar solo después de que done suba.
    output logic                         done,                              // Pulso de un ciclo que sube cuando el resultado está listo.
                                                                            // En el mismo ciclo, digit contiene la predicción válida. Fuera de ese ciclo, done vale 0.
    output logic [DIGIT_WIDTH-1:0]       digit                              // Predicción final (0..9) sobre 5 bits. Su valor solo es válido cuando done está alto;
                                                                            // entre inferencias puede quedar en cualquier valor.
);

  // Señales de flops
  t_acc acc;     // Acumulador de suma de productos y bias
  t_acc acc_nxt;

  t_hidden_act [NUM_HIDDEN_NEURONS-1:0] hidden_act;     // Memoria de activaciones de la capa de neuronas oculta 16x8 bits
  t_hidden_act [NUM_HIDDEN_NEURONS-1:0] hidden_act_nxt; // Activacion oculta (despues de ReLU + >>5 + clamp 255)

  logic         is_higher_score; // Resultado de la comparacion que indica si el score actual es mayor que el mejor score hasta ahora (argmax)
  t_final_score argmax;          // Argmax al vuelo con comparador signed inicializado en best_score = 32’h8000_0000 (el mínimo int32 representable).
  t_final_score argmax_nxt;      // Los 10 scores de la capa de neuronas de salida van directo al argmax como int32 con signo.
                                 // La comparación es signed, y en caso de empate gana el primer índice recorrido.

  t_digit predicted_digit;     // Digito predicho (0..9)
  t_digit predicted_digit_nxt; // Guarda el indice de la neurona de salida con el score mas alto (argmax)

  // Señales de ROMs
  t_weight [NUM_MULS-1:0] weights; // Pesos de la capa oculta y de la capa de salida (8 por lectura de la ROM de pesos)
  t_bias                  bias;    // Bias de la capa oculta y de la capa de salida (1 por lectura de la ROM de bias)

  logic [WEIGHTS_ROM_ADDR_WIDTH-1:0] weights_rom_addr; // Direccion de lectura de la ROM de pesos
  logic [BIASES_ROM_ADDR_WIDTH -1:0] biases_rom_addr;  // Direccion de lectura de la ROM de bias

  // Señales de FMA dot-product
  logic [NUM_MULS-1:0][FMA_DP_SRCA_WIDTH  -1:0] fma_dp_srca;   // Capa 1: Pixel (uint4) o Capa 2: Activacion de neurona oculta (uint8) para cada multiplicador en paralelo
  logic [NUM_MULS-1:0][FMA_DP_SRCB_WIDTH  -1:0] fma_dp_srcb;   // Capa 1: Pesos de la neurona oculta (int8) o Capa 2: Pesos de la neurona de salida (int8) para cada multiplicador en paralelo
  logic               [FMA_DP_SRCC_WIDTH  -1:0] fma_dp_srcc;   // Bias de cada neurona (int32) o acumulador
  logic               [FMA_DP_RESULT_WIDTH-1:0] fma_dp_result; // Resultado parcial de la suma de productos y bias (int32) de cada neurona

  t_pixel_ext      [NUM_PIXELS_GROUPS        -1:0][NUM_MULS-1:0] pixels_group;
  t_hidden_act_ext [NUM_HIDDEN_NEURONS_GROUPS-1:0][NUM_MULS-1:0] hidden_acts_group;

  // Señales de control FSM
  t_pixels_group_idx         sel_pixels_group;         // Selector de grupo de pixeles (3 bits para 8 grupos)
  t_hidden_neurons_group_idx sel_hidden_neurons_group; // Selector de grupo de neuronas ocultas (1 bit para 2 grupos)
  t_hidden_neuron_idx        sel_hidden_neuron;        // Selector de neurona oculta (4 bits para 16 neuronas)
  t_output_neuron_idx        sel_output_neuron;        // Selector de neurona de salida (4 bits para 10 neuronas)
  logic                      is_layer_1;
  logic                      is_pass_0;
  logic                      acc_en;
  logic                      acc_rst;
  logic                      hidden_neuron_en;
  logic                      output_neuron_en;
  logic                      neuron_rst;

  // Delay flops
  logic [FMA_DP_RESULT_WIDTH-1:0] delayed_fma_dp_result;
  logic                           delayed_output_neuron_en;
  t_output_neuron_idx             delayed_sel_output_neuron;

  /////////////////////////////////////////////////////////////
  // FMA dot-product
  /////////////////////////////////////////////////////////////

  // Multiplicadores en paralelo con arbol de CSAs
  fma_dp #(
    .NUM_MULS  (NUM_MULS         ),
    .SRC1_WIDTH(FMA_DP_SRCA_WIDTH),
    .SRC2_WIDTH(FMA_DP_SRCB_WIDTH),
    .SRC3_WIDTH(FMA_DP_SRCC_WIDTH)
  ) fma_dp (
    .srca     (fma_dp_srca  ),
    .srcb     (fma_dp_srcb  ),
    .srcc     (fma_dp_srcc  ),
    .is_signed(1'b1         ),
    .result   (fma_dp_result)
  );

  // Seleccion de operandos para el FMA dot-product
  always_comb begin
    // Pasar imagen a formato de fila de pixeles extendidos con 0 para forzar que sea positivo
    // Coinciden el numero de grupos con el numero de filas de la imagen y el numero de pixeles por grupo con el numero de columnas de la imagen (8x8)
    for (int row = 0; row < IMAGE_VERTICAL_SIZE; row++) begin
      for (int col = 0; col < IMAGE_HORIZONTAL_SIZE; col++) begin
        pixels_group[row][col] = {{(FMA_DP_SRCA_WIDTH-IMAGE_PIXEL_WIDTH){1'b0}}, image[row][col]};
      end
    end
    // Pasar activaciones de la capa de neuronas oculta a formato de grupo de 8 extendidos con 0 para forzar que sea positivo
    for (int neuron = 0; neuron < NUM_HIDDEN_NEURONS; neuron++) begin
      hidden_acts_group[neuron / NUM_MULS][neuron % NUM_MULS] = {{(FMA_DP_SRCA_WIDTH-HIDDEN_ACT_WIDTH){1'b0}}, hidden_act[neuron]};
    end

    // Source A
    fma_dp_srca = is_layer_1
                ? pixels_group     [sel_pixels_group        ]
                : hidden_acts_group[sel_hidden_neurons_group];

    // Source B
    fma_dp_srcb = weights;

    // Source C
    fma_dp_srcc = is_pass_0
                ? bias
                : acc;
  end

  /////////////////////////////////////////////////////////////
  // Control FSM
  /////////////////////////////////////////////////////////////

  control_fsm control_fsm
  (
    .clk(clk),
    .rst(rst),

    // Inicio y fin de procesamiento de la red neuronal
    .start(start),
    .done (done ),

    // Selectores
    .sel_pixels_group        (sel_pixels_group        ), // Selector de grupo de pixeles (3 bits para 8 grupos)
    .sel_hidden_neurons_group(sel_hidden_neurons_group), // Selector de grupo de neuronas ocultas (1 bit para 2 grupos)
    .sel_hidden_neuron       (sel_hidden_neuron       ), // Selector de neurona oculta (4 bits para 16 neuronas)
    .sel_output_neuron       (sel_output_neuron       ), // Selector de neurona de salida (4 bits para 10 neuronas)
    .is_layer_1              (is_layer_1              ),
    .is_pass_0               (is_pass_0               ),

    // Write enables y resets de neuronas y acumulador
    .acc_en          (acc_en          ),
    .acc_rst         (acc_rst         ),
    .hidden_neuron_en(hidden_neuron_en),
    .output_neuron_en(output_neuron_en),
    .neuron_rst      (neuron_rst      ),

    // Direcciones de lectura de ROMs
    .weights_rom_addr(weights_rom_addr),
    .biases_rom_addr (biases_rom_addr )
  );

  /////////////////////////////////////////////////////////////
  // ROMs
  /////////////////////////////////////////////////////////////

  weights_rom weights_rom (
    .addr   (weights_rom_addr),
    .weights(weights         )
  );

  biases_rom biases_rom (
    .addr(biases_rom_addr),
    .bias(bias           )
  );

  /////////////////////////////////////////////////////////////
  // Accumulator
  /////////////////////////////////////////////////////////////

  always_comb begin
    if (acc_rst) begin
      acc_nxt = '0;
    end else if (acc_en) begin
      acc_nxt = fma_dp_result;
    end else begin
      acc_nxt = acc;
    end
  end

  /////////////////////////////////////////////////////////////
  // Hidden neurons
  /////////////////////////////////////////////////////////////

  generate
    genvar hidden_neuron_idx;
    for (hidden_neuron_idx = 0; hidden_neuron_idx < NUM_HIDDEN_NEURONS; hidden_neuron_idx++) begin : gen_hidden_neuron
      logic is_selected;

      assign is_selected = (sel_hidden_neuron == hidden_neuron_idx);

      always_comb begin
        if (neuron_rst) begin
          hidden_act_nxt[hidden_neuron_idx] = '0;
        end else if (hidden_neuron_en & is_selected) begin
          // ReLU + >>5 + clamp 255
          hidden_act_nxt[hidden_neuron_idx] = f_requantize(fma_dp_result);
        end else begin
          hidden_act_nxt[hidden_neuron_idx] = hidden_act[hidden_neuron_idx];
        end
      end

    end : gen_hidden_neuron
  endgenerate

  /////////////////////////////////////////////////////////////
  // Output neurons
  /////////////////////////////////////////////////////////////

  // Argmax
  always_comb begin
    if (neuron_rst) begin
      argmax_nxt = ARGMAX_INIT;
    end else if (delayed_output_neuron_en) begin
      argmax_nxt = is_higher_score
                 ? delayed_fma_dp_result
                 : argmax;
    end else begin
      argmax_nxt = argmax;
    end
  end

  argmax_cmp argmax_cmp (
    .candidate_score   (delayed_fma_dp_result), // Se necesita flopear el resultado del FMA FP antes del comparador para no empeorar la ruta critica del FMA DP
    .current_best_score(argmax               ),
    .is_higher_score   (is_higher_score      )
  );

  // Predicted digit
  always_comb begin
    if (neuron_rst) begin
      predicted_digit_nxt = t_digit'(0);
    end else if (delayed_output_neuron_en) begin
      predicted_digit_nxt = is_higher_score
                          ? t_digit'(delayed_sel_output_neuron)
                          : predicted_digit;
    end else begin
      predicted_digit_nxt = predicted_digit;
    end
  end

  assign digit = predicted_digit_nxt;

  /////////////////////////////////////////////////////////////
  // Flops
  /////////////////////////////////////////////////////////////

  always_ff @(posedge clk) begin
    acc             <= acc_nxt;
    hidden_act      <= hidden_act_nxt;
    argmax          <= argmax_nxt;
    predicted_digit <= predicted_digit_nxt;
  end

  always_ff @(posedge clk) begin
    delayed_fma_dp_result     <= fma_dp_result;
    delayed_output_neuron_en  <= output_neuron_en;
    delayed_sel_output_neuron <= sel_output_neuron;
  end

endmodule : neural_network_digits

// Wrapper de funcion de comparacion signed para argmax
// Devuelve 1 si candidate_score es mayor que current_best_score, sino devuelve 0
// - Queremos que el comparador signed este dentro de un modulo para analizar los recursos
//   inferidos en sintesis ya que se utiliza el operador behavioral ">" en f_is_higher_score
module argmax_cmp
    import neural_network_pkg::*;
(
    input  t_final_score candidate_score,
    input  t_final_score current_best_score,
    output logic         is_higher_score
);

  assign is_higher_score = f_is_higher_score(candidate_score, current_best_score);

endmodule : argmax_cmp
