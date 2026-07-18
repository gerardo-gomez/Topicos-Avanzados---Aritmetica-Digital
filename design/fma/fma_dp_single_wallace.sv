// Description: Dot-Product Fused Multiply-Add (FMA DP) module. Computes a dot product of two vectors (srca and srcb) and adds a scalar (srcc) fused with the sum of the partial products from each multiplier.
//              result = (srca[0] * srcb[0]) + (srca[1] * srcb[1]) + ... + (srca[N-1] * srcb[N-1]) + srcc
//              The purpose of this module is to be used in the Neural Network for digits classification.
//              In that application the multiplications are always signed, so the logic to support unsigned operands was optimized out.

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

  // Partial products parameters
  localparam int PP_WIDTH       = SRC1_WIDTH + SRC2_WIDTH;   // Width of each partial product from the multipliers (before Wallace tree reduction)
  localparam int NUM_PP_PER_MUL = (SRC2_WIDTH / 2)           // Number of partial products for booth radix-4
                                + (SRC2_WIDTH % 2)           // Add 1 if SRC2_WIDTH is odd
                                + 1;                         // +1 for the constant correction bits
  localparam int NUM_TOTAL_PP   = NUM_MULS * NUM_PP_PER_MUL;

  // Wallace tree parameters
  localparam int WALLACE_NUM_OPERANDS_IN  = NUM_TOTAL_PP                 // Wallace tree operands to reduce are all partial products from each multiplier
                                          + 1;                           // +1 for the scalar addend (srcc)
  localparam int WALLACE_NUM_OPERANDS_OUT = 2;                           // Wallace tree reduces to 2 operands
  localparam int WALLACE_SRCC_FMA_IDX     = WALLACE_NUM_OPERANDS_IN - 1;

  logic [NUM_MULS    -1:0][NUM_PP_PER_MUL-1:0][PP_WIDTH    -1:0] mul_pp;     // Partial products from each multiplier
  logic [NUM_TOTAL_PP-1:0]                    [RESULT_WIDTH-1:0] mul_pp_ext; // All partial products extended to RESULT_WIDTH and flattened

  logic                               [RESULT_WIDTH-1:0] srcc_ext;
  logic [WALLACE_NUM_OPERANDS_IN -1:0][RESULT_WIDTH-1:0] wallace_operands_in;
  logic [WALLACE_NUM_OPERANDS_OUT-1:0][RESULT_WIDTH-1:0] wallace_operands_out;

  generate
    genvar mul;
    genvar pp;
    for (mul = 0; mul < NUM_MULS; mul++) begin : gen_mul
      booth4_pp #(
        .SRC1_WIDTH(SRC1_WIDTH),
        .SRC2_WIDTH(SRC2_WIDTH)
      ) booth4_pp (
        .srca(srca  [mul]),
        .srcb(srcb  [mul]),
        .pp  (mul_pp[mul])
      );

      // Extend each partial product to RESULT_WIDTH and flatten the array for the FMA Wallace tree
      for (pp = 0; pp < NUM_PP_PER_MUL; pp++) begin : gen_pp
        assign mul_pp_ext[(mul*NUM_PP_PER_MUL) + pp] = {{(RESULT_WIDTH - PP_WIDTH){mul_pp[mul][pp][PP_WIDTH-1]}}, mul_pp[mul][pp]};
      end : gen_pp
    end : gen_mul
  endgenerate

  // FMA source C Add operand 
  // Sign-extended srcc to RESULT_WIDTH for addition fused with the sum of the multipliers partial products (FMA)
  assign srcc_ext = {{(RESULT_WIDTH - SRC3_WIDTH){srcc[SRC3_WIDTH-1]}}, srcc}; 

  // Sum of all partial products
  always_comb begin
    wallace_operands_in[NUM_TOTAL_PP-1:0]     = mul_pp_ext; // Add all partial products
    wallace_operands_in[WALLACE_SRCC_FMA_IDX] = srcc_ext;   // Add FMA source C operand
  end

  wallace_tree #(
    .WIDTH (RESULT_WIDTH           ),
    .NUM_IN(WALLACE_NUM_OPERANDS_IN)
  ) wallace_tree (
    .operands_in (wallace_operands_in ),
    .operands_out(wallace_operands_out)
  );

  cla #(
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
