// Description: Carry Look-Ahead Adder (N-bits)
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

  logic [3:0][3:0] cla4_a;
  logic [3:0][3:0] cla4_b;
  logic [3:0]      cla4_cin;
  logic [3:0][3:0] cla4_sum;
  logic [3:0]      cla4_gg;
  logic [3:0]      cla4_pg;

  logic [4:1]      lcu4_cout;

  lcu4 lcu4 (
    .g   (cla4_gg  ),
    .p   (cla4_pg  ),
    .cin (cin      ),
    .cout(lcu4_cout),
    .gg  (         ),
    .pg  (         )
  );

  cla4 cla4_0 (
    .a  (cla4_a  [0]),
    .b  (cla4_b  [0]),
    .cin(cla4_cin[0]),
    .sum(cla4_sum[0]),
    .gg (cla4_gg [0]),
    .pg (cla4_pg [0])
  );

  cla4 cla4_1 (
    .a  (cla4_a  [1]),
    .b  (cla4_b  [1]),
    .cin(cla4_cin[1]),
    .sum(cla4_sum[1]),
    .gg (cla4_gg [1]),
    .pg (cla4_pg [1])
  );

  cla4 cla4_2 (
    .a  (cla4_a  [2]),
    .b  (cla4_b  [2]),
    .cin(cla4_cin[2]),
    .sum(cla4_sum[2]),
    .gg (cla4_gg [2]),
    .pg (cla4_pg [2])
  );

  cla4 cla4_3 (
    .a  (cla4_a  [3]),
    .b  (cla4_b  [3]),
    .cin(cla4_cin[3]),
    .sum(cla4_sum[3]),
    .gg (cla4_gg [3]),
    .pg (cla4_pg [3])
  );

  always_comb begin
    cla4_a[0] = srca[ 3: 0];
    cla4_a[1] = srca[ 7: 4];
    cla4_a[2] = srca[11: 8];
    cla4_a[3] = srca[15:12];

    cla4_b[0] = srcb[ 3: 0];
    cla4_b[1] = srcb[ 7: 4];
    cla4_b[2] = srcb[11: 8];
    cla4_b[3] = srcb[15:12];

    cla4_cin[0] = cin;
    cla4_cin[1] = lcu4_cout[1];
    cla4_cin[2] = lcu4_cout[2];
    cla4_cin[3] = lcu4_cout[3];
    cout        = lcu4_cout[4];

    result[ 3: 0] = cla4_sum[0];
    result[ 7: 4] = cla4_sum[1];
    result[11: 8] = cla4_sum[2];
    result[15:12] = cla4_sum[3];
  end

  // Flags
  assign zero_f = ~(|result);
  assign ov_f   = is_signed
                ? ((srca[WIDTH-1] ^ result[WIDTH-1]) & (srcb[WIDTH-1] ^ result[WIDTH-1])) // Overflow para signed:   si el signo del resultado es diferente al de ambos operandos
                : cout;                                                                   // Overflow para unsigned: si hay carry de salida

endmodule
