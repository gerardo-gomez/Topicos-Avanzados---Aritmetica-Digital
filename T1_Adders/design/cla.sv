// Description: Carry Look-Ahead Adder (N-bits)
// Contact:     Gerardo Gomez

module adder #(
//parameter int WIDTH = 16             // Ancho del adder
  parameter int WIDTH = 4              // Ancho del adder
)(
  input  logic [WIDTH-1:0] srca,       // Operando 1
  input  logic [WIDTH-1:0] srcb,       // Operando 2
  input  logic             cin,        // Carry de entrada
  input  logic             is_signed,  // Indica si la operacion es signed(1) o unsigned(0)
  output logic [WIDTH-1:0] result,     // Resultado
  output logic             cout,       // Carry de salida
  output logic             zero_f,     // Bandera de cero
  output logic             ov_f        // Bandera de overflow
); 

  cla4 cla4 (
    .a   (srca  ),
    .b   (srcb  ),
    .cin (cin   ),
    .sum (result),
    .cout(cout  )
  );

  // Flags
  assign zero_f = ~(|result);
  assign ov_f   = is_signed
                ? ((srca[WIDTH-1] ^ result[WIDTH-1]) & (srcb[WIDTH-1] ^ result[WIDTH-1])) // Overflow para signed:   si el signo del resultado es diferente al de ambos operandos
                : cout;                                                                   // Overflow para unsigned: si hay carry de salida

endmodule
