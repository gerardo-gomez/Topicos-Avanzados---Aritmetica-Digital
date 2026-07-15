// Descripcion: Paquete con los parametros de la red neuronal clasificadora de digitos y funciones auxiliares
// Parametros fijos (NO MODIFICAR)

package neural_network_pkg;

  /////////////////////////////////////////////////////////////
  // Parametros de cuantizacion entera
  /////////////////////////////////////////////////////////////

  parameter int WEIGHT_WIDTH      = 8;  // Pesos capa 1 y 2
  parameter int BIAS_WIDTH        = 32; // Bias capa 1 y 2
  parameter int ACC_WIDTH         = 32; // Acumulador
  parameter int HIDDEN_ACT_WIDTH  = 8;  // Activacion oculta (despues de ReLU + >>5 + clamp 255)
  parameter int FINAL_SCORE_WIDTH = 32; // Score final (crudo, sin ReLU ni shift)

  typedef logic [WEIGHT_WIDTH     -1:0] t_weight;
  typedef logic [BIAS_WIDTH       -1:0] t_bias;
  typedef logic [ACC_WIDTH        -1:0] t_acc;
  typedef logic [HIDDEN_ACT_WIDTH -1:0] t_hidden_act;
  typedef logic [FINAL_SCORE_WIDTH-1:0] t_final_score;

  /////////////////////////////////////////////////////////////
  // Otros parametros de la arquitectura de la red
  /////////////////////////////////////////////////////////////

  parameter int NUM_HIDDEN_NEURONS = 16; // Numero de neuronas en la capa oculta
  parameter int NUM_OUTPUT_NEURONS = 10; // Numero de neuronas en la capa de salida (una por digito)
  parameter int NUM_TOTAL_NEURONS  = NUM_HIDDEN_NEURONS + NUM_OUTPUT_NEURONS;

  parameter int NUM_LAYERS = 2;

  parameter int SEL_HIDDEN_NEURON_WIDTH = $clog2(NUM_HIDDEN_NEURONS); // Ancho del selector de neurona oculta (4 bits para 16 neuronas)
  parameter int SEL_OUTPUT_NEURON_WIDTH = $clog2(NUM_OUTPUT_NEURONS); // Ancho del selector de neurona de salida (4 bits para 10 neuronas)
  parameter int SEL_GLOBAL_NEURON_WIDTH  = $clog2(NUM_TOTAL_NEURONS);  // Ancho del selector de neurona total (5 bits para 26 neuronas)

  typedef logic [SEL_HIDDEN_NEURON_WIDTH-1:0] t_hidden_neuron_idx;
  typedef logic [SEL_OUTPUT_NEURON_WIDTH-1:0] t_output_neuron_idx;
  typedef logic [SEL_GLOBAL_NEURON_WIDTH-1:0] t_global_neuron_idx;

  parameter t_final_score ARGMAX_INIT = 32'h8000_0000; // Valor inicial del argmax (el minimo int32 representable)

  /////////////////////////////////////////////////////////////
  // Parametros de la imagen
  /////////////////////////////////////////////////////////////

  parameter int IMAGE_PIXEL_WIDTH     = 4; // Bits por píxel (uint4, 0..15)
  parameter int IMAGE_HORIZONTAL_SIZE = 8; // Columnas de la imagen
  parameter int IMAGE_VERTICAL_SIZE   = 8; // Filas de la imagen
//parameter int DIGIT_WIDTH           = 5; // Bits de la salida (rango 0..9, sobra un bit)
  parameter int DIGIT_WIDTH           = 4; // En el TB se usan 4 bits para el digito

  parameter int NUM_PIXELS = IMAGE_HORIZONTAL_SIZE * IMAGE_VERTICAL_SIZE; // Numero de pixeles en la imagen (8x8 = 64)

  typedef logic [IMAGE_PIXEL_WIDTH-1:0] t_pixel;
  typedef logic [DIGIT_WIDTH      -1:0] t_digit;

  /////////////////////////////////////////////////////////////
  // Parametros especificos de la implementacion
  /////////////////////////////////////////////////////////////

  parameter int NUM_MULS                 = 8;                             // Numero de multiplicadores en paralelo en FMA dot-product
  parameter int FMA_DP_SRCA_WIDTH        = HIDDEN_ACT_WIDTH + 1;          // Ancho de operando A del FMA dot-product: Activacion oculta (mas ancho) o pixel + 1 para forzar que los valores siempre sean positivos
  parameter int FMA_DP_SRCB_WIDTH        = WEIGHT_WIDTH;                  // Ancho de operando B del FMA dot-product: Pesos
  parameter int FMA_DP_SRCC_WIDTH        = BIAS_WIDTH;                    // Ancho de operando C del FMA dot-product: Bias o acumulador (mismo ancho)
  parameter int FMA_DP_RESULT_WIDTH      = FMA_DP_SRCC_WIDTH;             // Ancho de resultado del FMA dot-product: FMA_DP_SRCC_WIDTH > (FMA_DP_SRCA_WIDTH + FMA_DP_SRCB_WIDTH)

  parameter int NUM_PIXELS_GROUPS         = NUM_PIXELS         / NUM_MULS; // Numero de grupos de pixeles (64 pixeles / 8 multiplicadores = 8 grupos)
  parameter int NUM_HIDDEN_NEURONS_GROUPS = NUM_HIDDEN_NEURONS / NUM_MULS; // Numero de grupos de neuronas ocultas (16 neuronas / 8 multiplicadores = 2 grupos)

  parameter int SEL_PIXELS_GROUP_WIDTH         = $clog2(NUM_PIXELS_GROUPS        ); // Ancho del selector de grupo de pixeles (3 bits para 8 grupos)
  parameter int SEL_HIDDEN_NEURONS_GROUP_WIDTH = $clog2(NUM_HIDDEN_NEURONS_GROUPS); // Ancho del selector de grupo de neuronas ocultas (1 bit para 2 grupos)

  typedef logic [SEL_PIXELS_GROUP_WIDTH        -1:0] t_pixels_group_idx;
  typedef logic [SEL_HIDDEN_NEURONS_GROUP_WIDTH-1:0] t_hidden_neurons_group_idx;
  typedef logic [FMA_DP_SRCA_WIDTH             -1:0] t_pixel_ext;                // Tipo de dato para un pixel extendido con 0 para ajustarse a ancho de operando de multiplicador y forzar que sea positivo
  typedef logic [FMA_DP_SRCA_WIDTH             -1:0] t_hidden_act_ext;           // Tipo de dato para una activacion oculta extendido con 0 para ajustarse a ancho de operando de multiplicador y forzar que sea positivo

  /////////////////////////////////////////////////////////////
  // Parametros de las ROMs de pesos y bias
  /////////////////////////////////////////////////////////////

  // Original memory layout: layer1: 16 neurons x 64 int8 weights, then layer2: 10 x 16 = total 1184 8-bit entries
  // Adjusted memory layout to read 8 weight values per read (1184 / 8):                = total 148 64-bit entries
  parameter int WEIGHTS_ROM_DEPTH      = ((NUM_HIDDEN_NEURONS * NUM_PIXELS) + (NUM_OUTPUT_NEURONS * NUM_HIDDEN_NEURONS)) / NUM_MULS;
  parameter int WEIGHTS_ROM_ADDR_WIDTH = $clog2(WEIGHTS_ROM_DEPTH); // 148 entradas de 64 bits (8 pesos por entrada).
  parameter int WEIGHTS_ROM_DATA_WIDTH = NUM_MULS * WEIGHT_WIDTH;   // 8 pesos de 8 bits = 64 bits por entrada
  parameter     WEIGHTS_ROM_FILE       = "./design/neural_network/weights.hex";
  // Memory layout: 16 layer-1 biases then 10 layer-2 biases, int32 = total 26 32-bit entries
  parameter int BIASES_ROM_DEPTH       = NUM_TOTAL_NEURONS;
  parameter int BIASES_ROM_ADDR_WIDTH  = $clog2(BIASES_ROM_DEPTH);  // 26 entradas de 32 bits (1 bias por entrada).
  parameter int BIASES_ROM_DATA_WIDTH  = BIAS_WIDTH;                // 1 bias de 32 bits por entrada
  parameter     BIASES_ROM_FILE        = "./design/neural_network/biases.hex";

  /////////////////////////////////////////////////////////////
  // Parametros de control FSM
  /////////////////////////////////////////////////////////////

  typedef enum logic [1:0] {
    IDLE,
    LAYER_1,
    LAYER_2,
    DONE
  } t_state;

  parameter int NUM_LAYER_1_PASSES = NUM_PIXELS         / NUM_MULS; // 64 pixeles / 8 multiplicadores = 8 pasadas por neurona oculta
  parameter int NUM_LAYER_2_PASSES = NUM_HIDDEN_NEURONS / NUM_MULS; // 16 neuronas ocultas / 8 multiplicadores = 2 pasadas por neurona de salida

  parameter int COUNTER_PASSES_WIDTH  = $clog2(NUM_LAYER_1_PASSES + 1);
  parameter int COUNTER_NEURONS_WIDTH = $clog2(BIASES_ROM_DEPTH   + 1); // Or $clog2(NUM_TOTAL_NEURONS) = $clog(26)
  parameter int COUNTER_WEIGHTS_WIDTH = $clog2(WEIGHTS_ROM_DEPTH  + 1); // 8 weights per count, we need to count 148 for the 1184 weights

  /////////////////////////////////////////////////////////////
  // Funciones auxiliares
  /////////////////////////////////////////////////////////////

  // Funcion de recuantizacion: ReLU + >>5 + clamp 255
  function automatic t_hidden_act f_requantize(input t_acc acc);
    t_acc        acc_relu;
    t_acc        acc_shifted;
    t_acc        acc_clamped;
    t_hidden_act hidden_act;
    acc_relu    = (acc[ACC_WIDTH-1])                           // ReLU: si el MSB es 1 (negativo) entonces 0, sino el valor original
                ? 0
                : acc;
    acc_shifted = {{5{1'b0}}, acc_relu[ACC_WIDTH-1:5]};        // acc_relu >> 5: Shift a la derecha 5 bits (dividir entre 32)
    acc_clamped = (|acc_shifted[ACC_WIDTH-1:HIDDEN_ACT_WIDTH]) // Clamp a [0,255]. Si es mayor que 255 entonces saturar a 255, sino el valor original
                ? {ACC_WIDTH{1'b1}}
                : acc_shifted;
    hidden_act  = acc_clamped[HIDDEN_ACT_WIDTH-1:0];           // Tomar los 8 bits menos significativos
    return hidden_act;
  endfunction

  // Funcion de comparacion signed para argmax
  // Devuelve 1 si candidate_score es mayor que current_best_score, sino devuelve 0
  function automatic logic f_is_higher_score(input t_final_score candidate_score, input t_final_score current_best_score);
    return ($signed(candidate_score) > $signed(current_best_score));
  endfunction

  // Funcion que convierte un indice global de neurona (0..25) a un indice de neurona de salida (0..9)
  function automatic t_output_neuron_idx f_convert_global_to_output_neuron_idx(input t_global_neuron_idx global_neuron_idx);
    unique case (global_neuron_idx)
      5'h10:   return t_output_neuron_idx'(0); // global neuron index 16 = output neuron index 0
      5'h11:   return t_output_neuron_idx'(1); // global neuron index 17 = output neuron index 1
      5'h12:   return t_output_neuron_idx'(2); // global neuron index 18 = output neuron index 2
      5'h13:   return t_output_neuron_idx'(3); // global neuron index 19 = output neuron index 3
      5'h14:   return t_output_neuron_idx'(4); // global neuron index 20 = output neuron index 4
      5'h15:   return t_output_neuron_idx'(5); // global neuron index 21 = output neuron index 5
      5'h16:   return t_output_neuron_idx'(6); // global neuron index 22 = output neuron index 6
      5'h17:   return t_output_neuron_idx'(7); // global neuron index 23 = output neuron index 7
      5'h18:   return t_output_neuron_idx'(8); // global neuron index 24 = output neuron index 8
      5'h19:   return t_output_neuron_idx'(9); // global neuron index 25 = output neuron index 9
      default: return '1;                      // Not an output neuron
    endcase
  endfunction

endpackage
