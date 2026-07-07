// Description: Fused Multiply-Add (FMA) module based on Booth radix-4 multiplier and Wallace tree adder (booth4_wallace_mul.sv)

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

  localparam int SRCA_WIDTH     = SRC1_WIDTH;
  localparam int SRCB_WIDTH     = SRC2_WIDTH;
  localparam int SRCB_EXT_WIDTH = SRC2_WIDTH + 1;             // Additional bit to support unsigned multiplications
  localparam int SRCC_WIDTH     = SRC3_WIDTH;

  localparam int BOOTH_RADIX         = 4;
  localparam int BOOTH_TRIPLET_SIZE  = 3;                     // $clog2(BOOTH_RADIX) + 1 = 3 for radix-4
  localparam int BOOTH_PP_TABLE_SIZE = 2**BOOTH_TRIPLET_SIZE; // Number of encoded triplets to partial products. 2^3 = 8 for radix-4
  localparam int BOOTH_NUM_PP        = (SRCB_EXT_WIDTH / 2)   // Number of partial products for radix-4
                                     + (SRCB_EXT_WIDTH % 2);  // Add 1 if SRCB_EXT_WIDTH is odd
  localparam int BOOTH_SHIFT_AMOUNT  = $clog2(BOOTH_RADIX);   // Amount to shift each partial product. 2 for radix-4

  typedef logic [BOOTH_TRIPLET_SIZE-1:0] t_booth_triplet;

  logic                             [SRCB_EXT_WIDTH-1:0] srcb_ext;
  t_booth_triplet [BOOTH_NUM_PP-1:0]                     triplet;
  logic           [BOOTH_NUM_PP-1:0][RESULT_WIDTH-1:0]   pp;
  logic           [BOOTH_NUM_PP-1:0][RESULT_WIDTH-1:0]   pp_shifted;
  logic                             [RESULT_WIDTH-1:0]   comp2_corr;

  // Signals for sum of partial products
  localparam int WALLACE_NUM_OPERANDS_IN  = BOOTH_NUM_PP
                                          + 1            // +1 for the constant correction bits (comp2_corr)
                                          + 1;           // +1 for FMA source C Add operand (srcc_fma_pp)
  localparam int WALLACE_NUM_OPERANDS_OUT = 2;           // Wallace tree reduces to 2 operands
  localparam int WALLACE_COMP2_CORR_IDX   = WALLACE_NUM_OPERANDS_IN - 2;
  localparam int WALLACE_SRCC_FMA_IDX     = WALLACE_NUM_OPERANDS_IN - 1;

  logic [WALLACE_NUM_OPERANDS_IN-1:0] [RESULT_WIDTH-1:0] wallace_operands_in;
  logic [WALLACE_NUM_OPERANDS_OUT-1:0][RESULT_WIDTH-1:0] wallace_operands_out;

  // Signals for FMA
  logic                             [RESULT_WIDTH-1:0]   srcc_fma_pp;

  // Function that groups the bits of srcb into triplets for radix-4 Booth encoding
  // Triplets are formed with overlap of 1 bit. Example for srcb[7:0]: (b_7 b_6 b_5), (b_5 b_4 b_3), (b_3 b_2 b_1), (b_1 b_0 b_(-1))
  function automatic t_booth_triplet f_get_booth_triplet(input int pp_idx, input logic [SRCB_EXT_WIDTH-1:0] srcb);
    logic [(SRCB_EXT_WIDTH + (SRCB_EXT_WIDTH % 2) + 1)-1:0] srcb_ext;
    // Extend (further) srcb with auxiliary 0 at LSB for triplet grouping (b_(-1) = 0).
    // Also extend srcb sign an additional bit at MSB if SRCB_EXT_WIDTH is odd to make it even for triplet grouping,
    srcb_ext = {{(SRCB_EXT_WIDTH % 2){srcb[SRCB_EXT_WIDTH-1]}}, srcb, 1'b0};
    return {srcb_ext[(2*pp_idx + 1) + 1], srcb_ext[(2*pp_idx + 1) + 0], srcb_ext[(2*pp_idx + 1) - 1]};
  endfunction

  // Function that returns a booth partial product based on the encoded triplet
  // Table of encoded triplets to partial products (radix-4):
  //   b_(i+1), b_i, b_(i-1)
  //         0,   0,   0 -> 0
  //         0,   0,   1 -> +1A
  //         0,   1,   0 -> +1A
  //         0,   1,   1 -> +2A
  //         1,   0,   0 -> -2A
  //         1,   0,   1 -> -1A
  //         1,   1,   0 -> -1A
  //         1,   1,   1 -> 0
  // Note: Partial products don't use the complete 2's complement of srca.
  //       Instead, 1's complement is used and the result is corrected by injecting constant 1s to the final sum of partial products.
  function automatic logic [RESULT_WIDTH-1:0] f_get_booth_pp(input t_booth_triplet triplet, input logic [SRCA_WIDTH-1:0] srca, input logic is_signed);
    logic [RESULT_WIDTH-1:0] srca_sign_ext = {{SRCB_WIDTH{srca[SRCA_WIDTH-1] & is_signed}}, srca};
    unique case (triplet)
      3'b001, 3'b010: return   srca_sign_ext      ; // +A
      3'b011:         return  (srca_sign_ext << 1); // +2A
      3'b100:         return ~(srca_sign_ext << 1); // -2A
      3'b101, 3'b110: return ~(srca_sign_ext     ); // -A
      default:        return                    '0; // 0A (3'b000 or 3'b111)
    endcase
  endfunction

  function automatic logic f_is_booth_pp_comp2(input t_booth_triplet triplet);
//  return (triplet inside {3'b100, 3'b101, 3'b110}); // -A, -2A
    return ( (triplet == 3'b100)
           | (triplet == 3'b101)
           | (triplet == 3'b110)); // inside {} not supported by Quartus
  endfunction

  always_comb begin
    // Use extended srcb with an additional bit at MSB to support unsigned multiplications:
    // - If the multiplication is signed, srcb sign is extended to the extra bit.
    // - If the multiplication is unsigned, srcb extra bit is set to 0 acting as the new srcb sign.
    srcb_ext = {(srcb[SRCB_WIDTH-1] & is_signed), srcb};

    // Initialize the 2's complement correction to 0
    comp2_corr = '0;

    for (int pp_idx = 0; pp_idx < BOOTH_NUM_PP; pp_idx++) begin
      // Group srcb bits into triplets
      triplet[pp_idx] = f_get_booth_triplet(pp_idx, srcb_ext);

      // Get the partial products based on the encoded triplets.
      // is_signed is evaluated to check if srca sign is extended in the partial products.
      pp[pp_idx] = f_get_booth_pp(triplet[pp_idx], srca, is_signed);

      // Compute the partial product correction for 2's complement
      comp2_corr[pp_idx * BOOTH_SHIFT_AMOUNT] = f_is_booth_pp_comp2(triplet[pp_idx]);
    end
  end

  // Shift the partial products according to their weight
  generate
    genvar pp_idx;
    for (pp_idx = 0; pp_idx < BOOTH_NUM_PP; pp_idx++) begin : gen_pp_shifted
      assign pp_shifted[pp_idx] = {pp[pp_idx][(RESULT_WIDTH - (pp_idx * BOOTH_SHIFT_AMOUNT))-1:0], {(pp_idx * BOOTH_SHIFT_AMOUNT){1'b0}}};
    end : gen_pp_shifted
  endgenerate

  // FMA source C Add operand 
  // Sign-extended srcc to RESULT_WIDTH for addition along with the sum of the multiplier partial products (FMA)
  always_comb begin
    srcc_fma_pp = is_fma
                ? {{(RESULT_WIDTH - SRCC_WIDTH){srcc[SRCC_WIDTH-1] & is_signed}}, srcc}
                : '0;
  end

  // Sum of all partial products
  always_comb begin
    wallace_operands_in[BOOTH_NUM_PP-1:0]       = pp_shifted;
    wallace_operands_in[WALLACE_COMP2_CORR_IDX] = comp2_corr;  // Add the 2's complement correction
    wallace_operands_in[WALLACE_SRCC_FMA_IDX]   = srcc_fma_pp; // Add FMA source C operand
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
