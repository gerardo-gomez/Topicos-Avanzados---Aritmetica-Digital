// Descripcion: Top level del adder para implementacion en FPGA y analisis de timing

module fpga_top #(
  parameter int WIDTH = 16             // Ancho del adder
)(
  input  logic clk,

  input  logic [WIDTH-1:0] srca_in,       // Operando 1
  input  logic [WIDTH-1:0] srcb_in,       // Operando 2
  input  logic             cin_in,        // Carry de entrada
  input  logic             is_signed_in,  // Indica si la operacion es signed(1) o unsigned(0)
  output logic [WIDTH-1:0] result_out,    // Resultado
  output logic             cout_out,      // Carry de salida
  output logic             zero_f_out,    // Bandera de cero
  output logic             ov_f_out       // Bandera de overflow
); 

  // Flopped FPGA inputs signals
  // FF.D
  logic [WIDTH-1:0] srca_d;
  logic [WIDTH-1:0] srcb_d;
  logic             cin_d;
  logic             is_signed_d;
  // FF.Q
  logic [WIDTH-1:0] srca_q;
  logic [WIDTH-1:0] srcb_q;
  logic             cin_q;
  logic             is_signed_q;

  // Flopped FPGA outputs signals
  // FF.D
  logic [WIDTH-1:0] result_d;
  logic             cout_d;
  logic             zero_f_d;
  logic             ov_f_d;
  // FF.Q
  logic [WIDTH-1:0] result_q;
  logic             cout_q;
  logic             zero_f_q;
  logic             ov_f_q;

  // Adder instance signals
  logic [WIDTH-1:0] srca;
  logic [WIDTH-1:0] srcb;
  logic             cin;
  logic             is_signed;
  logic [WIDTH-1:0] result;
  logic             cout;
  logic             zero_f;
  logic             ov_f;

  //////////////////////////////////////////////////////////////////////////////////////
  // Instantiate adder
  //////////////////////////////////////////////////////////////////////////////////////

  adder #(
    .WIDTH(WIDTH)
  ) cla (
    .srca     (srca     ), // Operando 1
    .srcb     (srcb     ), // Operando 2
    .cin      (cin      ), // Carry de entrada
    .is_signed(is_signed), // Indica si la operacion es signed(1) o unsigned(0)
    .result   (result   ), // Resultado
    .cout     (cout     ), // Carry de salida
    .zero_f   (zero_f   ), // Bandera de cero
    .ov_f     (ov_f     )  // Bandera de overflow
  );

  //////////////////////////////////////////////////////////////////////////////////////
  // Connect flopped adder instance signals
  //////////////////////////////////////////////////////////////////////////////////////

  // Flopped FPGA inputs to adder instance inputs
  assign srca      = srca_q;
  assign srcb      = srcb_q;
  assign cin       = cin_q;
  assign is_signed = is_signed_q;

  // Flopped adder instance outputs to FPGA outputs
  assign result_out = result_q;
  assign cout_out   = cout_q;
  assign zero_f_out = zero_f_q;
  assign ov_f_out   = ov_f_q;

  //////////////////////////////////////////////////////////////////////////////////////
  // Flop FPGA ports
  //////////////////////////////////////////////////////////////////////////////////////

  // Connect FPGA inputs to FF.D
  assign srca_d      = srca_in;
  assign srcb_d      = srcb_in;
  assign cin_d       = cin_in;
  assign is_signed_d = is_signed_in;

  // Connect adder instance outputs to FF.D
  assign result_d = result;
  assign cout_d   = cout;
  assign zero_f_d = zero_f;
  assign ov_f_d   = ov_f;

  // Flop FPGA inputs
  always_ff @(posedge clk) begin
    srca_q      <= srca_d;
    srcb_q      <= srcb_d;
    cin_q       <= cin_d;
    is_signed_q <= is_signed_d;
  end

  // Flop adder instance outputs
  always_ff @(posedge clk) begin
    result_q <= result_d;
    cout_q   <= cout_d;
    zero_f_q <= zero_f_d;
    ov_f_q   <= ov_f_d;
  end

endmodule
