// Description: "Fused Multiply-Add (FMA)" using multiplier and adder instances as 2 independent operations, first the multiplier and then the adder (for comparison purposes vs real FMA hardware)

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

  logic [RESULT_WIDTH-1:0] mul_result;
  logic [RESULT_WIDTH-1:0] srcc_ext;

  multiplier #(
    .SRC1_WIDTH(SRC1_WIDTH),
    .SRC2_WIDTH(SRC2_WIDTH)
  ) multiplier (
    .srca     (srca      ),
    .srcb     (srcb      ),
    .is_signed(is_signed ),
    .result   (mul_result)
  );

  adder #(
    .WIDTH(RESULT_WIDTH)
  ) adder (
    .srca      (mul_result),
    .srcb      (srcc_ext  ),
    .cin       (1'b0      ),
    .is_signed (1'b0      ),
    .result    (result    ),
    .cout      (          ),
    .zero_f    (          ),
    .ov_f      (          )
  ); 

  assign srcc_ext = is_fma
                  ? {{(RESULT_WIDTH - SRC3_WIDTH){srcc[SRC3_WIDTH-1] & is_signed}}, srcc}
                  : '0;

endmodule
