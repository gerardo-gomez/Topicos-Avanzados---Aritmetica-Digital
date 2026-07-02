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

  localparam int SRCA_WIDTH = SRC1_WIDTH;
  localparam int SRCB_WIDTH = SRC2_WIDTH;

  localparam int BOOTH_RADIX         = 4;
  localparam int BOOTH_TRIPLET_SIZE  = 3;                       // $clog2(BOOTH_RADIX) + 1 = 3 for radix-4
  localparam int BOOTH_PP_TABLE_SIZE = 2**BOOTH_TRIPLET_SIZE;   // Number of encoded triplets to partial products. 2^3 = 8 for radix-4
  localparam int BOOTH_NUM_PP        = SRCB_WIDTH / 2;          // Number of partial products for radix-4
  localparam int BOOTH_SHIFT_AMOUNT  = $clog2(BOOTH_RADIX);     // Amount to shift each partial product. 2 for radix-4

  typedef logic [BOOTH_TRIPLET_SIZE-1:0] t_booth_triplet;

  logic                             [SRCA_WIDTH  -1:0] srca_comp2;
  t_booth_triplet [BOOTH_NUM_PP-1:0]                   booth_triplet;
  logic           [BOOTH_NUM_PP-1:0][RESULT_WIDTH-1:0] booth_pp;
  logic           [BOOTH_NUM_PP-1:0][RESULT_WIDTH-1:0] booth_pp_shifted;

  // Function that groups the bits of srcb into triplets for radix-4 Booth encoding
  // Triplets are formed with overlap of 1 bit. Example for SRCB_WIDTH=8: (b_7 b_6 b_5), (b_5 b_4 b_3), (b_3 b_2 b_1), (b_1 b_0 b_(-1))
  function automatic t_booth_triplet f_get_booth_triplet(input int pp_idx, input logic [SRCB_WIDTH-1:0] srcb);
    logic [(SRCB_WIDTH + 1)-1:0] srcb_ext;
    // Extend srcb with auxiliary 0 at LSB for triplet grouping (b_(-1) = 0)
    srcb_ext = {srcb, 1'b0};
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
  function automatic logic [RESULT_WIDTH-1:0] f_get_booth_pp(input t_booth_triplet triplet, input logic [SRCA_WIDTH-1:0] srca, input logic [SRCA_WIDTH-1:0] srca_comp2);
    unique case (triplet)
      3'b000, 3'b111: return '0;                                                                                         // 0A
      3'b001, 3'b010: return {{ SRCB_WIDTH   {srca      [SRCA_WIDTH-1] & is_signed}},                 srca            }; // +A
      3'b011:         return {{(SRCB_WIDTH-1){srca      [SRCA_WIDTH-1] & is_signed}}, (SRCA_WIDTH+1)'(srca       << 1)}; // +2A
      3'b100:         return {{(SRCB_WIDTH-1){srca_comp2[SRCA_WIDTH-1] & is_signed}}, (SRCA_WIDTH+1)'(srca_comp2 << 1)}; // -2A
      3'b101, 3'b110: return {{ SRCB_WIDTH   {srca_comp2[SRCA_WIDTH-1] & is_signed}},                 srca_comp2      }; // -A
    endcase
  endfunction

  always_comb begin
    // 2's complement of srca
    srca_comp2 = ~srca + 1'b1;

    for (int pp_idx = 0; pp_idx < BOOTH_NUM_PP; pp_idx++) begin
      // Group srcb bits into triplets
      booth_triplet[pp_idx] = f_get_booth_triplet(pp_idx, srcb);

      // Get the partial products based on the encoded triplets
      booth_pp[pp_idx] = f_get_booth_pp(booth_triplet[pp_idx], srca, srca_comp2);
    end
  end

  // Shift the partial products according to their weight
  generate
    for (genvar pp_idx = 0; pp_idx < BOOTH_NUM_PP; pp_idx++) begin : gen_pp_shifted
      assign booth_pp_shifted[pp_idx] = {booth_pp[pp_idx][(RESULT_WIDTH - (pp_idx * BOOTH_SHIFT_AMOUNT))-1:0], {(pp_idx * BOOTH_SHIFT_AMOUNT){1'b0}}};
    end : gen_pp_shifted
  endgenerate

  // Sum of all partial products
  always_comb begin
    result = 0;
    for (int pp_idx = 0; pp_idx < BOOTH_NUM_PP; pp_idx++) begin
      result += booth_pp_shifted[pp_idx];
    end
  end

endmodule

// Typical implementation of an array multiplier: only supports unsigned numbers and is slow because the partial products are summed in cascade.
// module array_mul #(parameter N = 8) (
//   input  logic [N-1:0]   a, b,
//   output logic [2*N-1:0] p
// );
//
//   logic [N-1:0] pp [N];
//
//   always_comb begin
//     for (int j = 0; j < N; j++)
//       pp[j] = a & {N{b[j]}};
//   end
//
//   always_comb begin
//     p = '0;
//       for (int j = 0; j < N; j++)
//         p = p + ({{N{1'b0}}, pp[j]} << j);
//   end
// endmodule

// Idiomatic form of an array multiplier (synthesis decides the architecture):
//   assign p = a * b;
