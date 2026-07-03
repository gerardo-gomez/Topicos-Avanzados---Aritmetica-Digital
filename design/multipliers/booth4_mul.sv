// Description: Radix-4 / modified Booth multiplier that adds partial products in cascade (TODO: add them using Wallace / CSA and CPA)

module multiplier #(
  parameter  int SRC1_WIDTH   =  32,
  parameter  int SRC2_WIDTH   =  SRC1_WIDTH,
  localparam int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH)
) (
  input  logic [SRC1_WIDTH-1:0]   srca,
  input  logic [SRC2_WIDTH-1:0]   srcb,
  input  logic                    is_signed,
  output logic [RESULT_WIDTH-1:0] result
);

  localparam int SRCA_WIDTH     = SRC1_WIDTH;
  localparam int SRCB_WIDTH     = SRC2_WIDTH;
  localparam int SRCB_EXT_WIDTH = SRC2_WIDTH + 1;             // Additional bit to support unsigned multiplications

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
    return (triplet inside {3'b100, 3'b101, 3'b110}); // -A, -2A
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
    for (genvar pp_idx = 0; pp_idx < BOOTH_NUM_PP; pp_idx++) begin : gen_pp_shifted
      assign pp_shifted[pp_idx] = {pp[pp_idx][(RESULT_WIDTH - (pp_idx * BOOTH_SHIFT_AMOUNT))-1:0], {(pp_idx * BOOTH_SHIFT_AMOUNT){1'b0}}};
    end : gen_pp_shifted
  endgenerate

  // Sum of all partial products
  always_comb begin
    result = 0;
    for (int pp_idx = 0; pp_idx < BOOTH_NUM_PP; pp_idx++) begin
      result += pp_shifted[pp_idx];
    end
    result += comp2_corr; // Add the 2's complement correction
  end

endmodule
