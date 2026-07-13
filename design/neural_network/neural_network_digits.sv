// Clasificador de digitos con red neuronal sobre un FMA tipo producto punto (dot-product FMA)

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

endmodule
