// Descripcion: Top level del FMA para implementacion en FPGA y analisis de timing

module fpga_top #(
  parameter  int SRC1_WIDTH   = 64,
  parameter  int SRC2_WIDTH   = SRC1_WIDTH,
  parameter  int SRC3_WIDTH   = SRC1_WIDTH,
//localparam int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH)
  parameter  int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH) // DON'T CHANGE (localparam not supported by Quartus)
)(
  input  logic clk,

  input  logic [SRC1_WIDTH-1:0]   srca_in,      // Operando 1 del multiplicador
  input  logic [SRC2_WIDTH-1:0]   srcb_in,      // Operando 2 del multiplicador
  input  logic [SRC3_WIDTH-1:0]   srcc_in,      // Operando del sumador cuando is_fma = 1
  input  logic                    is_fma_in,    // Indica si la operacion es FMA(1) o solo multiplicacion(0)
  input  logic                    is_signed_in, // Indica si la operacion es signed(1) o unsigned(0)
  output logic [RESULT_WIDTH-1:0] result_out    // Resultado
);

  // Flopped FPGA inputs signals
  // FF.D
  logic [SRC1_WIDTH-1:0] srca_d;
  logic [SRC2_WIDTH-1:0] srcb_d;
  logic [SRC3_WIDTH-1:0] srcc_d;
  logic                  is_fma_d;
  logic                  is_signed_d;
  // FF.Q
  logic [SRC1_WIDTH-1:0] srca_q;
  logic [SRC2_WIDTH-1:0] srcb_q;
  logic [SRC3_WIDTH-1:0] srcc_q;
  logic                  is_fma_q;
  logic                  is_signed_q;

  // Flopped FPGA outputs signals
  // FF.D
  logic [RESULT_WIDTH-1:0] result_d;
  // FF.Q
  logic [RESULT_WIDTH-1:0] result_q;

  // FMA instance signals
  logic [SRC1_WIDTH-1:0]   srca;
  logic [SRC2_WIDTH-1:0]   srcb;
  logic [SRC3_WIDTH-1:0]   srcc;
  logic                    is_fma;
  logic                    is_signed;
  logic [RESULT_WIDTH-1:0] result;

  //////////////////////////////////////////////////////////////////////////////////////
  // Instantiate fma
  //////////////////////////////////////////////////////////////////////////////////////

  fma #(
    .SRC1_WIDTH(SRC1_WIDTH),
    .SRC2_WIDTH(SRC2_WIDTH),
    .SRC3_WIDTH(SRC3_WIDTH)
  ) fma_split (
    .srca     (srca     ),
    .srcb     (srcb     ),
    .srcc     (srcc     ),
    .is_fma   (is_fma   ),
    .is_signed(is_signed),
    .result   (result   )
  );

  //////////////////////////////////////////////////////////////////////////////////////
  // Connect flopped fma instance signals
  //////////////////////////////////////////////////////////////////////////////////////

  // Flopped FPGA inputs to fma instance inputs
  assign srca      = srca_q;
  assign srcb      = srcb_q;
  assign srcc      = srcc_q;
  assign is_fma    = is_fma_q;
  assign is_signed = is_signed_q;

  // Flopped fma instance outputs to FPGA outputs
  assign result_out = result_q;

  //////////////////////////////////////////////////////////////////////////////////////
  // Flop FPGA ports
  //////////////////////////////////////////////////////////////////////////////////////

  // Connect FPGA inputs to FF.D
  assign srca_d      = srca_in;
  assign srcb_d      = srcb_in;
  assign srcc_d      = srcc_in;
  assign is_fma_d    = is_fma_in;
  assign is_signed_d = is_signed_in;

  // Connect fma instance outputs to FF.D
  assign result_d = result;

  // Flop FPGA inputs
  always_ff @(posedge clk) begin
    srca_q      <= srca_d;
    srcb_q      <= srcb_d;
    srcc_q      <= srcc_d;
    is_fma_q    <= is_fma_d;
    is_signed_q <= is_signed_d;
  end

  // Flop fma instance outputs
  always_ff @(posedge clk) begin
    result_q <= result_d;
  end

endmodule
