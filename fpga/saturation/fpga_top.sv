// Descripcion: Top level del sumador con saturacion para implementacion en FPGA y analisis de timing

module fpga_top #(
  parameter int WIDTH = 32
)(
  input  logic clk,

  input  logic [WIDTH-1:0] srca_in,
  input  logic [WIDTH-1:0] srcb_in,
  input  logic             sat_to_max_in,
  input  logic [WIDTH-1:0] max_sat_value_in,
  input  logic             sat_to_min_in,
  input  logic [WIDTH-1:0] min_sat_value_in,
  input  logic             cin_in,
  input  logic             is_signed_in,
  output logic [WIDTH-1:0] result_out
);

  // Flopped FPGA inputs signals
  // FF.D
  logic [WIDTH-1:0] srca_d;
  logic [WIDTH-1:0] srcb_d;
  logic             sat_to_max_d;
  logic [WIDTH-1:0] max_sat_value_d;
  logic             sat_to_min_d;
  logic [WIDTH-1:0] min_sat_value_d;
  logic             cin_d;
  logic             is_signed_d;
  // FF.Q
  logic [WIDTH-1:0] srca_q;
  logic [WIDTH-1:0] srcb_q;
  logic             sat_to_max_q;
  logic [WIDTH-1:0] max_sat_value_q;
  logic             sat_to_min_q;
  logic [WIDTH-1:0] min_sat_value_q;
  logic             cin_q;
  logic             is_signed_q;

  // Flopped FPGA outputs signals
  // FF.D
  logic [WIDTH-1:0] result_d;
  // FF.Q
  logic [WIDTH-1:0] result_q;

  // Adder_sat instance signals
  logic [WIDTH-1:0] srca;
  logic [WIDTH-1:0] srcb;
  logic             sat_to_max;
  logic [WIDTH-1:0] max_sat_value;
  logic             sat_to_min;
  logic [WIDTH-1:0] min_sat_value;
  logic             cin;
  logic             is_signed;
  logic [WIDTH-1:0] result;

  //////////////////////////////////////////////////////////////////////////////////////
  // Instantiate adder_sat
  //////////////////////////////////////////////////////////////////////////////////////

  adder_sat #(
    .WIDTH(WIDTH)
  ) adder_sat (
    .srca         (srca         ),
    .srcb         (srcb         ),
    .sat_to_max   (sat_to_max   ),
    .max_sat_value(max_sat_value),
    .sat_to_min   (sat_to_min   ),
    .min_sat_value(min_sat_value),
    .cin          (cin          ),
    .is_signed    (is_signed    ),
    .result       (result       )
  );

  //////////////////////////////////////////////////////////////////////////////////////
  // Connect flopped adder_sat instance signals
  //////////////////////////////////////////////////////////////////////////////////////

  // Flopped FPGA inputs to adder_sat instance inputs
  assign srca          = srca_q;
  assign srcb          = srcb_q;
  assign sat_to_max    = sat_to_max_q;
  assign max_sat_value = max_sat_value_q;
  assign sat_to_min    = sat_to_min_q;
  assign min_sat_value = min_sat_value_q;
  assign cin           = cin_q;
  assign is_signed     = is_signed_q;

  // Flopped adder_sat instance outputs to FPGA outputs
  assign result_out = result_q;

  //////////////////////////////////////////////////////////////////////////////////////
  // Flop FPGA ports
  //////////////////////////////////////////////////////////////////////////////////////

  // Connect FPGA inputs to FF.D
  assign srca_d          = srca_in;
  assign srcb_d          = srcb_in;
  assign sat_to_max_d    = sat_to_max_in;
  assign max_sat_value_d = max_sat_value_in;
  assign sat_to_min_d    = sat_to_min_in;
  assign min_sat_value_d = min_sat_value_in;
  assign cin_d           = cin_in;
  assign is_signed_d     = is_signed_in;

  // Connect adder_sat instance outputs to FF.D
  assign result_d = result;

  // Flop FPGA inputs
  always_ff @(posedge clk) begin
    srca_q          <= srca_d;
    srcb_q          <= srcb_d;
    sat_to_max_q    <= sat_to_max_d;
    max_sat_value_q <= max_sat_value_d;
    sat_to_min_q    <= sat_to_min_d;
    min_sat_value_q <= min_sat_value_d;
    cin_q           <= cin_d;
    is_signed_q     <= is_signed_d;
  end

  // Flop adder_sat instance outputs
  always_ff @(posedge clk) begin
    result_q <= result_d;
  end

endmodule
