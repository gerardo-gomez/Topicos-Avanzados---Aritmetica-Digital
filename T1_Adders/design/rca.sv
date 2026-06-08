// Description: Ripple Carry Adder
// Contact:     Gerardo Gomez

module adder #(
  parameter int WIDTH = 16             // Ancho del adder
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

  logic [WIDTH:0] c;

  assign c[0] = cin;

  genvar i;
  generate
    for (i = 0; i < WIDTH; i = i + 1) begin : fa_chain
      full_adder fa (
        .a   (srca  [i]  ),
        .b   (srcb  [i]  ),
        .cin (c     [i]  ),
        .sum (result[i]  ),
        .cout(c     [i+1])
      );
    end
  endgenerate

  assign cout = c[WIDTH];

  // Flags
  assign zero_f = ~(|result);
  assign ov_f   = is_signed
                ? ((srca[WIDTH-1] ^ result[WIDTH-1]) & (srcb[WIDTH-1] ^ result[WIDTH-1])) // Overflow para signed:   si el signo del resultado es diferente al de ambos operandos
                : cout;                                                                   // Overflow para unsigned: si hay carry de salida

`ifdef VERIF
  logic [WIDTH-1:0] sva_result;
  logic             sva_cout;

  assign {sva_cout, sva_result} = srca + srcb + cin;

  result_check: assert property (disable iff (ov_f)
    (result == sva_result)
  ) else $error("Adder result mismatch (signed = %0d): A + B + Cin = 0x%0h + 0x%0h + 0x%0h = 0x%0h (expected 0x%0h)",
                is_signed, srca, srcb, cin, result, sva_result);

  cout_check: assert property (
    (cout == sva_cout)
  ) else $error("Carry out mismatch (signed = %0d): A + B + Cin = 0x%0h + 0x%0h + 0x%0h = 0x%0h (expected 0x%0h), cout = %0d (expected %0d)",
                is_signed, srca, srcb, cin, result, sva_result, cout, sva_cout);

  zero_flag_check: assert property (
    (zero_f == (result == 0))
  ) else $error("Zero flag mismatch: result = 0x%0h, zero_f = %0d (expected %0d)",
                result, zero_f, (result == 0));

  overflow_flag_check: assert property (
    ((ov_f) |-> (result != sva_result))
  ) else $error("Overflow flag set on correct result (signed = %0d): A + B + Cin = 0x%0h + 0x%0h + 0x%0h = 0x%0h (expected 0x%0h), ov_f = %0d",
                is_signed, srca, srcb, cin, result, sva_result, ov_f);
`endif

endmodule
