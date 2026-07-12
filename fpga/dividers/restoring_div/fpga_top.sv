// Descripcion: Top level del divisor restoring para implementacion en FPGA y analisis de timing

module fpga_top #(
  parameter int WIDTH = 64
)(
  input  logic clk,

  input  logic [WIDTH-1:0] srca_in,
  input  logic [WIDTH-1:0] srcb_in,
  input  logic             is_signed_in,
  output logic [WIDTH-1:0] result_out,
  output logic [WIDTH-1:0] rem_out,
  output logic             div_zero_f_out
);

  // Flopped FPGA inputs signals
  // FF.D
  logic [WIDTH-1:0] srca_d;
  logic [WIDTH-1:0] srcb_d;
  logic             is_signed_d;
  // FF.Q
  logic [WIDTH-1:0] srca_q;
  logic [WIDTH-1:0] srcb_q;
  logic             is_signed_q;

  // Flopped FPGA outputs signals
  // FF.D
  logic [WIDTH-1:0] result_d;
  logic [WIDTH-1:0] rem_d;
  logic             div_zero_f_d;
  // FF.Q
  logic [WIDTH-1:0] result_q;
  logic [WIDTH-1:0] rem_q;
  logic             div_zero_f_q;

  // Divider instance signals
  logic [WIDTH-1:0] srca;
  logic [WIDTH-1:0] srcb;
  logic             is_signed;
  logic [WIDTH-1:0] result;
  logic [WIDTH-1:0] rem;
  logic             div_zero_f;

  //////////////////////////////////////////////////////////////////////////////////////
  // Instantiate divider
  //////////////////////////////////////////////////////////////////////////////////////

  divider #(
    .WIDTH(WIDTH)
  ) divider (
    .clk       (clk       ),
    .srca      (srca      ),
    .srcb      (srcb      ),
    .is_signed (is_signed ),
    .result    (result    ),
    .rem       (rem       ),
    .div_zero_f(div_zero_f)
  );

  //////////////////////////////////////////////////////////////////////////////////////
  // Connect flopped divider instance signals
  //////////////////////////////////////////////////////////////////////////////////////

  // Flopped FPGA inputs to divider instance inputs
  assign srca      = srca_q;
  assign srcb      = srcb_q;
  assign is_signed = is_signed_q;

  // Flopped divider instance outputs to FPGA outputs
  assign result_out     = result_q;
  assign rem_out        = rem_q;
  assign div_zero_f_out = div_zero_f_q;

  //////////////////////////////////////////////////////////////////////////////////////
  // Flop FPGA ports
  //////////////////////////////////////////////////////////////////////////////////////

  // Connect FPGA inputs to FF.D
  assign srca_d      = srca_in;
  assign srcb_d      = srcb_in;
  assign is_signed_d = is_signed_in;

  // Connect divider instance outputs to FF.D
  assign result_d     = result;
  assign rem_d        = rem;
  assign div_zero_f_d = div_zero_f;

  // Flop FPGA inputs
  always_ff @(posedge clk) begin
    srca_q      <= srca_d;
    srcb_q      <= srcb_d;
    is_signed_q <= is_signed_d;
  end

  // Flop divider instance outputs
  always_ff @(posedge clk) begin
    result_q     <= result_d;
    rem_q        <= rem_d;
    div_zero_f_q <= div_zero_f_d;
  end

endmodule
