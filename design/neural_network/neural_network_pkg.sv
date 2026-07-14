// Descripcion: Paquete con los parametros de la red neuronal clasificadora de digitos y funciones auxiliares
// Parametros fijos (NO MODIFICAR)

package neural_network_pkg;

  /////////////////////////////////////////////////////////////
  // Parametros de la imagen
  /////////////////////////////////////////////////////////////

  parameter int IMAGE_PIXEL_WIDTH     = 4; // Bits por píxel (uint4, 0..15)
  parameter int IMAGE_HORIZONTAL_SIZE = 8; // Columnas de la imagen
  parameter int IMAGE_VERTICAL_SIZE   = 8; // Filas de la imagen
  parameter int DIGIT_WIDTH           = 5; // Bits de la salida (rango 0..9, sobra un bit)

  parameter int NUM_PIXELS = IMAGE_HORIZONTAL_SIZE * IMAGE_VERTICAL_SIZE; // Numero de pixeles en la imagen (8x8 = 64)

  /////////////////////////////////////////////////////////////
  // Parametros de cuantizacion entera
  /////////////////////////////////////////////////////////////

  parameter int WEIGHT_WIDTH      = 8;  // Pesos capa 1 y 2
  parameter int BIAS_WIDTH        = 32; // Bias capa 1 y 2
  parameter int FMA_RESULT_WIDTH  = 16; // Producto de una celda FMA
  parameter int ACC_WIDTH         = 32; // Acumulador
  parameter int HIDDEN_ACT_WIDTH  = 8;  // Activacion oculta (despues de ReLU + >>5 + clamp 255)
  parameter int FINAL_SCORE_WIDTH = 32; // Score final (crudo, sin ReLU ni shift)

  /////////////////////////////////////////////////////////////
  // Otros parametros de la arquitectura de la red
  /////////////////////////////////////////////////////////////

  parameter int NUM_HIDDEN_NEURONS = 16; // Numero de neuronas en la capa oculta
  parameter int NUM_OUTPUT_NEURONS = 10; // Numero de neuronas en la capa de salida (una por digito)

  parameter int NUM_LAYERS = 2;

  /////////////////////////////////////////////////////////////
  // Parametros especificos de la implementacion
  /////////////////////////////////////////////////////////////

  parameter int NUM_MULS = 8; // Numero de multiplicadores en paralelo en FMA dot-product

  /////////////////////////////////////////////////////////////
  // Parametros de las ROMs de pesos y bias
  /////////////////////////////////////////////////////////////

  // Original memory layout: layer1: 16 neurons x 64 int8 weights, then layer2: 10 x 16 = total 1184 8-bit entries
  // Adjusted memory layout to read 8 weight values per read (1184 / 8):                = total 148 64-bit entries
  parameter int WEIGHTS_ROM_DEPTH      = 148;
  parameter int WEIGHTS_ROM_ADDR_WIDTH = $clog2(WEIGHTS_ROM_DEPTH); // 148 entradas de 64 bits (8 pesos por entrada). Ver weights_rom.sv para detalles
  parameter int WEIGHTS_ROM_DATA_WIDTH = NUM_MULS * WEIGHT_WIDTH;   // 8 pesos de 8 bits = 64 bits por entrada
  parameter     WEIGHTS_ROM_FILE       = "weights.hex";
  // Memory layout: 16 layer-1 biases then 10 layer-2 biases, int32 = total 26 32-bit entries
  parameter int BIASES_ROM_DEPTH       = 26;
  parameter int BIASES_ROM_ADDR_WIDTH  = $clog2(BIASES_ROM_DEPTH);  // 26 entradas de 32 bits (1 bias por entrada). Ver biases_rom.sv para detalles
  parameter int BIASES_ROM_DATA_WIDTH  = BIAS_WIDTH;
  parameter     BIASES_ROM_FILE        = "biases.hex";

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

  parameter int COUNTER_PASSES_WIDTH = $clog2(NUM_LAYER_1_PASSES                      + 1);
  parameter int COUNTER_NEURON_WIDTH = $clog2(NUM_HIDDEN_NEURONS + NUM_OUTPUT_NEURONS + 1);
  parameter int COUNTER_LAYER_WIDTH  = $clog2(NUM_LAYERS                              + 1);

  /////////////////////////////////////////////////////////////
  // Funciones auxiliares
  /////////////////////////////////////////////////////////////

  // Funcion de recuantizacion: ReLU + >>5 + clamp 255
  function automatic logic [HIDDEN_ACT_WIDTH-1:0] f_requantize(input logic [ACC_WIDTH-1:0] acc);
    logic [ACC_WIDTH-1:0]        acc_relu;
    logic [ACC_WIDTH-1:0]        acc_shifted;
    logic [ACC_WIDTH-1:0]        acc_clamped;
    logic [HIDDEN_ACT_WIDTH-1:0] act;
    acc_relu    = (acc[ACC_WIDTH-1])                           // ReLU: si el MSB es 1 (negativo) entonces 0, sino el valor original
                ? 0
                : acc;
    acc_shifted = acc_relu >> 5;                               // Shift a la derecha 5 bits (dividir entre 32)
    acc_clamped = (|acc_shifted[ACC_WIDTH-1:HIDDEN_ACT_WIDTH]) // Clamp a [0,255]. Si es mayor que 255 entonces saturar a 255, sino el valor original
                ? {ACC_WIDTH{1'b1}}
                : acc_shifted;
    act         = acc_clamped[HIDDEN_ACT_WIDTH-1:0];           // Tomar los 8 bits menos significativos
    return act;
  endfunction

  // Funcion de comparacion signed para argmax
  // Devuelve 1 si candidate_score es mayor que current_best_score, sino devuelve 0
  function automatic logic f_is_higher_score(input logic [FINAL_SCORE_WIDTH-1:0] candidate_score, input logic [FINAL_SCORE_WIDTH-1:0] current_best_score);
    return ($signed(candidate_score) > $signed(current_best_score));
  endfunction

endpackage
