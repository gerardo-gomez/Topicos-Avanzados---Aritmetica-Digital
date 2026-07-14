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

module neural_network_digits #(
    // Parametros fijos (NO MODIFICAR)
    parameter int IMAGE_PIXEL_WIDTH     = 4, // Bits por píxel (uint4, 0..15)
    parameter int IMAGE_HORIZONTAL_SIZE = 8, // Columnas de la imagen
    parameter int IMAGE_VERTICAL_SIZE   = 8, // Filas de la imagen
    parameter int DIGIT_WIDTH           = 5  // Bits de la salida (rango 0..9, sobra un bit)
) (
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

  localparam int NUM_PIXELS = 64; // Numero de pixeles en la imagen (8x8 = 64)

  // Parametros de cuantizacion entera
  localparam int WEIGHT_WIDTH      = 8;  // Pesos capa 1 y 2
  localparam int BIAS_WIDTH        = 32; // Bias capa 1 y 2
  localparam int FMA_RESULT_WIDTH  = 16; // Producto de una celda FMA
  localparam int ACC_WIDTH         = 32; // Acumulador
  localparam int HIDDEN_ACT_WIDTH  = 8;  // Activacion oculta (despues de ReLU + >>5 + clamp 255)
  localparam int FINAL_SCORE_WIDTH = 32; // Score final (crudo, sin ReLU ni shift)

  // Otros parametros de la arquitectura de la red
  localparam int NUM_HIDDEN_NEURONS = 16; // Numero de neuronas en la capa oculta
  localparam int NUM_OUTPUT_NEURONS = 10; // Numero de neuronas en la capa de salida (una por digito)

  // Parametros especificos de la implementacion
  localparam int NUM_MULS               = 8;           // Numero de multiplicadores en paralelo en FMA dot-product
  localparam int WEIGHTS_ROM_ADDR_WIDTH = $clog2(148); // 148 entradas de 64 bits (8 pesos por entrada). Ver weights_rom.sv para detalles
  localparam int BIASES_ROM_ADDR_WIDTH  = $clog2(26);  // 26 entradas de 32 bits (1 bias por entrada). Ver biases_rom.sv para detalles

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

  logic [ACC_WIDTH-1:0] acc;     // Acumulador de suma de productos y bias
  logic [ACC_WIDTH-1:0] acc_nxt;

  logic [NUM_HIDDEN_NEURONS-1:0][HIDDEN_ACT_WIDTH-1:0] hidden_act;     // Memoria de activaciones de la capa de neuronas oculta 16x8 bits
  logic [NUM_HIDDEN_NEURONS-1:0][HIDDEN_ACT_WIDTH-1:0] hidden_act_nxt; // Activacion oculta (despues de ReLU + >>5 + clamp 255)

  logic [FINAL_SCORE_WIDTH-1:0] argmax;     // Argmax al vuelo con comparador signed inicializado en best_score = 32’h8000_0000 (el mínimo int32 representable).
  logic [FINAL_SCORE_WIDTH-1:0] argmax_nxt; // Los 10 scores de la capa de neuronas de salida van directo al argmax como int32 con signo.
                                            // La comparación es signed, y en caso de empate gana el primer índice recorrido.

  logic [DIGIT_WIDTH-1:0] predicted_digit;     // Digito predicho (0..9)
  logic [DIGIT_WIDTH-1:0] predicted_digit_nxt; // Guarda el indice de la neurona de salida con el score mas alto (argmax)

  logic [NUM_MULS-1:0][WEIGHT_WIDTH-1:0] weights; // Pesos de la capa oculta y de la capa de salida (8 por lectura de la ROM de pesos)
  logic               [BIAS_WIDTH  -1:0] bias;    // Bias de la capa oculta y de la capa de salida (1 por lectura de la ROM de bias)

  logic [WEIGHTS_ROM_ADDR_WIDTH-1:0] weights_rom_addr; // Direccion de lectura de la ROM de pesos
  logic [BIASES_ROM_ADDR_WIDTH -1:0] biases_rom_addr;  // Direccion de lectura de la ROM de bias

  logic [NUM_MULS-1:0][HIDDEN_ACT_WIDTH-1:0] fma_dp_srca;   // Capa 1: Pixel (uint4) o Capa 2: Activacion de neurona oculta (uint8) para cada multiplicador en paralelo
  logic [NUM_MULS-1:0][WEIGHT_WIDTH    -1:0] fma_dp_srcb;   // Capa 1: Pesos de la neurona oculta (int8) o Capa 2: Pesos de la neurona de salida (int8) para cada multiplicador en paralelo
  logic               [BIAS_WIDTH      -1:0] fma_dp_srcc;   // Bias de cada neurona (int32) o acumulador
  logic               [ACC_WIDTH       -1:0] fma_dp_result; // Resultado parcial de la suma de productos y bias (int32) de cada neurona

  /////////////////////////////////////////////////////////////
  // FMA dot-product
  /////////////////////////////////////////////////////////////

  // Multiplicadores en paralelo con arbol de CSAs
  fma_dp #(
    .NUM_MULS  (NUM_MULS        ),
    .SRC1_WIDTH(HIDDEN_ACT_WIDTH),
    .SRC2_WIDTH(WEIGHT_WIDTH    ),
    .SRC3_WIDTH(BIAS_WIDTH      ),
  ) fma_dp (
    .srca     (fma_dp_srca  ),
    .srcb     (fma_dp_srcb  ),
    .srcc     (fma_dp_srcc  ),
    .is_signed(1'b1         ),
    .result   (fma_dp_result)
  );

  /////////////////////////////////////////////////////////////
  // Control FSM
  /////////////////////////////////////////////////////////////

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
  // Flops
  /////////////////////////////////////////////////////////////

  always_ff @(posedge clk) begin
    acc             <= acc_nxt;
    hidden_act      <= hidden_act_nxt;
    argmax          <= argmax_nxt;
    predicted_digit <= predicted_digit_nxt;
  end

endmodule
