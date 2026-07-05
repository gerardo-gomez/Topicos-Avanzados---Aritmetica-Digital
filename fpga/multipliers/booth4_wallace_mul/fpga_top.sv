// Descripcion: Top level del multiplier para implementacion en FPGA y analisis de timing

module fpga_top #(
  parameter  int SRC1_WIDTH   = 32,
  parameter  int SRC2_WIDTH   = SRC1_WIDTH,
//localparam int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH)
  parameter  int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH) // DON'T CHANGE (localparam not supported by Quartus)
)(
  input  logic clk,

  input  logic [SRC1_WIDTH-1:0]   srca_in,      // Operando 1
  input  logic [SRC2_WIDTH-1:0]   srcb_in,      // Operando 2
  input  logic                    is_signed_in, // Indica si la operacion es signed(1) o unsigned(0)
  output logic [RESULT_WIDTH-1:0] result_out    // Resultado
);

  // Flopped FPGA inputs signals
  // FF.D
  logic [SRC1_WIDTH-1:0] srca_d;
  logic [SRC2_WIDTH-1:0] srcb_d;
  logic                  is_signed_d;
  // FF.Q
  logic [SRC1_WIDTH-1:0] srca_q;
  logic [SRC2_WIDTH-1:0] srcb_q;
  logic                  is_signed_q;

  // Flopped FPGA outputs signals
  // FF.D
  logic [RESULT_WIDTH-1:0] result_d;
  // FF.Q
  logic [RESULT_WIDTH-1:0] result_q;

  // Multiplier instance signals
  logic [SRC1_WIDTH-1:0]   srca;
  logic [SRC2_WIDTH-1:0]   srcb;
  logic                    is_signed;
  logic [RESULT_WIDTH-1:0] result;

  //////////////////////////////////////////////////////////////////////////////////////
  // Instantiate multiplier
  //////////////////////////////////////////////////////////////////////////////////////

  multiplier #(
    .SRC1_WIDTH(SRC1_WIDTH),
    .SRC2_WIDTH(SRC2_WIDTH)
  ) booth4_wallace_mul (
    .srca     (srca     ), // Operando 1
    .srcb     (srcb     ), // Operando 2
    .is_signed(is_signed), // Indica si la operacion es signed(1) o unsigned(0)
    .result   (result   )  // Resultado
  );

  //////////////////////////////////////////////////////////////////////////////////////
  // Connect flopped multiplier instance signals
  //////////////////////////////////////////////////////////////////////////////////////

  // Flopped FPGA inputs to multiplier instance inputs
  assign srca      = srca_q;
  assign srcb      = srcb_q;
  assign is_signed = is_signed_q;

  // Flopped multiplier instance outputs to FPGA outputs
  assign result_out = result_q;

  //////////////////////////////////////////////////////////////////////////////////////
  // Flop FPGA ports
  //////////////////////////////////////////////////////////////////////////////////////

  // Connect FPGA inputs to FF.D
  assign srca_d      = srca_in;
  assign srcb_d      = srcb_in;
  assign is_signed_d = is_signed_in;

  // Connect multiplier instance outputs to FF.D
  assign result_d = result;

  // Flop FPGA inputs
  always_ff @(posedge clk) begin
    srca_q      <= srca_d;
    srcb_q      <= srcb_d;
    is_signed_q <= is_signed_d;
  end

  // Flop multiplier instance outputs
  always_ff @(posedge clk) begin
    result_q <= result_d;
  end

endmodule
