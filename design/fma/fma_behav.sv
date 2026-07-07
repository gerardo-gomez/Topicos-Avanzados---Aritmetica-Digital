// Description: Fused Multiply-Add (FMA) behavioral model

module fma #(
  parameter  int SRC1_WIDTH   = 64,
  parameter  int SRC2_WIDTH   = SRC1_WIDTH,
  parameter  int SRC3_WIDTH   = SRC1_WIDTH,
//localparam int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH)
  parameter  int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH) // DON'T CHANGE (localparam not supported by Quartus)
) (
  input  logic [SRC1_WIDTH-1:0]   srca, // Multiplier operand 1
  input  logic [SRC2_WIDTH-1:0]   srcb, // Multiplier operand 2
  input  logic [SRC3_WIDTH-1:0]   srcc, // Adder operand when is_fma = 1
  input  logic                    is_fma,
  input  logic                    is_signed,
  output logic [RESULT_WIDTH-1:0] result
);

  logic [RESULT_WIDTH-1:0] srca_ext;
  logic [RESULT_WIDTH-1:0] srcb_ext;
  logic [RESULT_WIDTH-1:0] srcc_ext;

  always_comb begin
    srca_ext = {{(RESULT_WIDTH - SRC1_WIDTH){srca[SRC1_WIDTH-1] & is_signed}}, srca};
    srcb_ext = {{(RESULT_WIDTH - SRC2_WIDTH){srcb[SRC2_WIDTH-1] & is_signed}}, srcb};
    srcc_ext = is_fma
             ? {{(RESULT_WIDTH - SRC3_WIDTH){srcc[SRC3_WIDTH-1] & is_signed}}, srcc}
             : '0;
  end

  // FMA behavioral model / Idiomatic form (synthesis decides the architecture)
  assign result = (srca_ext * srcb_ext) + srcc_ext;

endmodule
