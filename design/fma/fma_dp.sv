// Description: Dot-Product Fused Multiply-Add (FMA DP) module. Computes a dot product of two vectors (srca and srcb) and adds a scalar (srcc) fused with the sum of the partial results from each multiplier.
//              result = (srca[0] * srcb[0]) + (srca[1] * srcb[1]) + ... + (srca[N-1] * srcb[N-1]) + srcc

module fma_dp #(
  parameter  int NUM_MULS     = 8,                                         // Number of multiplications (vector size)
  parameter  int SRC1_WIDTH   = 8,                                         // Vector 1 width
  parameter  int SRC2_WIDTH   = SRC1_WIDTH,                                // Vector 2 width
  parameter  int SRC3_WIDTH   = 32,                                        // Scalar addend width
//localparam int RESULT_WIDTH = ( (SRC3_WIDTH > (SRC1_WIDTH + SRC2_WIDTH))
  parameter  int RESULT_WIDTH = ( (SRC3_WIDTH > (SRC1_WIDTH + SRC2_WIDTH)) // DON'T CHANGE (localparam not supported by Quartus)
                                ? (SRC3_WIDTH)
                                : (SRC1_WIDTH + SRC2_WIDTH))
) (
  input  logic [NUM_MULS-1:0][SRC1_WIDTH-1:0]   srca,      // Vector 1
  input  logic [NUM_MULS-1:0][SRC2_WIDTH-1:0]   srcb,      // Vector 2
  input  logic               [SRC3_WIDTH-1:0]   srcc,      // Scalar addend
  input  logic                                  is_signed,
  output logic               [RESULT_WIDTH-1:0] result
);

  localparam int WALLACE_NUM_OPERANDS_OUT = 2;                                   // Wallace tree reduces to 2 operands
  localparam int NUM_PARTIAL_RESULTS      = NUM_MULS * WALLACE_NUM_OPERANDS_OUT; // Each multiplier outputs 2 operands from their Wallace tree
  localparam int WALLACE_NUM_OPERANDS_IN  = NUM_PARTIAL_RESULTS                  // Wallace tree operands to reduce are the partial multiplier results (2 operands) from each multiplier (multipliers wallace trees output)
                                          + 1;                                   // +1 for the scalar addend (srcc)
  localparam int WALLACE_SRCC_FMA_IDX     = WALLACE_NUM_OPERANDS_IN - 1;
  localparam int PARTIAL_RESULT_WIDTH     = SRC1_WIDTH + SRC2_WIDTH;             // Width of each partial result from the multipliers (before Wallace tree reduction)

  logic [NUM_MULS           -1:0][WALLACE_NUM_OPERANDS_OUT-1:0][PARTIAL_RESULT_WIDTH-1:0] mul_result;
  logic [NUM_PARTIAL_RESULTS-1:0]                              [        RESULT_WIDTH-1:0] mul_result_ext; // Multiplier partial results extended to RESULT_WIDTH and flattened

  logic                               [RESULT_WIDTH-1:0] srcc_ext;
  logic [WALLACE_NUM_OPERANDS_IN -1:0][RESULT_WIDTH-1:0] wallace_operands_in;
  logic [WALLACE_NUM_OPERANDS_OUT-1:0][RESULT_WIDTH-1:0] wallace_operands_out;

  generate
    genvar mul;
    for (mul = 0; mul < NUM_MULS; mul++) begin : gen_mul
      multiplier #(
        .SRC1_WIDTH(SRC1_WIDTH),
        .SRC2_WIDTH(SRC2_WIDTH)
      ) booth4_wallace_no_cpa_mul (
        .srca          (srca      [mul]),
        .srcb          (srcb      [mul]),
        .is_signed     (is_signed      ),
        .wallace_result(mul_result[mul])
      );

      // Extend each partial result to RESULT_WIDTH and flatten the array for the FMA Wallace tree
      assign mul_result_ext[(mul*WALLACE_NUM_OPERANDS_OUT) +: WALLACE_NUM_OPERANDS_OUT] = {
        {{(RESULT_WIDTH - PARTIAL_RESULT_WIDTH){mul_result[mul][1][PARTIAL_RESULT_WIDTH-1] & is_signed}}, mul_result[mul][1]},
        {{(RESULT_WIDTH - PARTIAL_RESULT_WIDTH){mul_result[mul][0][PARTIAL_RESULT_WIDTH-1] & is_signed}}, mul_result[mul][0]}
      };
    end : gen_mul
  endgenerate

  // FMA source C Add operand 
  // Sign-extended srcc to RESULT_WIDTH for addition fused with the sum of the multipliers partial results (FMA)
  assign srcc_ext = {{(RESULT_WIDTH - SRC3_WIDTH){srcc[SRC3_WIDTH-1] & is_signed}}, srcc}; 

  // Sum of all partial multiplier results
  always_comb begin
    wallace_operands_in[NUM_PARTIAL_RESULTS-1:0] = mul_result_ext; // Add all partial multiplier results
    wallace_operands_in[WALLACE_SRCC_FMA_IDX]    = srcc_ext;       // Add FMA source C operand
  end

  wallace_tree #(
    .WIDTH (RESULT_WIDTH           ),
    .NUM_IN(WALLACE_NUM_OPERANDS_IN)
  ) wallace_tree (
    .operands_in (wallace_operands_in ),
    .operands_out(wallace_operands_out)
  );

  adder #(
    .WIDTH(RESULT_WIDTH)
  ) cla (
    .srca     (wallace_operands_out[0]),
    .srcb     (wallace_operands_out[1]),
    .cin      (1'b0                   ),
    .is_signed(1'b0                   ),
    .result   (result                 ),
    .cout     (                       ),
    .zero_f   (                       ),
    .ov_f     (                       )
  );

endmodule
