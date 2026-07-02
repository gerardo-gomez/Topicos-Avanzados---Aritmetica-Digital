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

  logic                   [ SRCA_WIDTH        -1:0] srca_comp2;
  logic [BOOTH_NUM_PP-1:0][ BOOTH_TRIPLET_SIZE-1:0] booth_triplet;
  logic [BOOTH_NUM_PP-1:0][(SRCA_WIDTH + 1)   -1:0] booth_pp;
  logic [BOOTH_NUM_PP-1:0]                          booth_pp_sign;
  logic [BOOTH_NUM_PP-1:0][ RESULT_WIDTH      -1:0] booth_pp_shifted;

  // Function that groups the bits of srcb into triplets for radix-4 Booth encoding
  // Triplets are formed with overlap of 1 bit. Example for SRCB_WIDTH=8: (b_7 b_6 b_5), (b_5 b_4 b_3), (b_3 b_2 b_1), (b_1 b_0 b_(-1))
  function automatic logic [BOOTH_TRIPLET_SIZE-1:0] get_booth_triplet(input int pp_idx, input logic [SRCB_WIDTH-1:0] srcb);
    logic [(SRCB_WIDTH + 1)-1:0] srcb_ext;
    // Extend srcb with auxiliary 0 at LSB for triplet grouping (b_(-1) = 0)
    srcb_ext = {srcb, 1'b0};
    return {srcb_ext[(2*pp_idx + 1) + 1], srcb_ext[(2*pp_idx + 1) + 0], srcb_ext[(2*pp_idx + 1) - 1]};
  endfunction

  // Function that returns a booth partial product based on the encoded triplet
  // Table of encoded triplets to partial products (radix-4)
  function automatic logic [(SRCA_WIDTH + 1)-1:0] get_booth_pp(input logic [BOOTH_TRIPLET_SIZE-1:0] triplet, input logic [SRCA_WIDTH-1:0] srca, input logic [SRCA_WIDTH-1:0] srca_comp2);
    unique case (triplet)                                // b_(i+1), b_i, b_(i-1)
      3'b000: return (SRCA_WIDTH + 1)'(0              ); //       0,   0,   0 -> 0
      3'b001: return (SRCA_WIDTH + 1)'(srca           ); //       0,   0,   1 -> +1A
      3'b010: return (SRCA_WIDTH + 1)'(srca           ); //       0,   1,   0 -> +1A
      3'b011: return (SRCA_WIDTH + 1)'(srca       << 1); //       0,   1,   1 -> +2A
      3'b100: return (SRCA_WIDTH + 1)'(srca_comp2 << 1); //       1,   0,   0 -> -2A
      3'b101: return (SRCA_WIDTH + 1)'(srca_comp2     ); //       1,   0,   1 -> -1A
      3'b110: return (SRCA_WIDTH + 1)'(srca_comp2     ); //       1,   1,   0 -> -1A
      3'b111: return (SRCA_WIDTH + 1)'(0              ); //       1,   1,   1 -> 0
    endcase
  endfunction

  // Function that returns the sign of a booth partial product given encoded triplet
  function automatic logic get_booth_pp_sign(input logic [BOOTH_TRIPLET_SIZE-1:0] triplet, input logic srca_sign);
    unique case (triplet)
      3'b000, 3'b111:         return 1'b0;
      3'b001, 3'b010, 3'b011: return srca_sign;
      3'b100, 3'b101, 3'b110: return ~srca_sign;
    endcase
  endfunction

  always_comb begin
    // 2's complement of srca
    srca_comp2 = ~srca + 1'b1;

    for (int pp_idx = 0; pp_idx < BOOTH_NUM_PP; pp_idx++) begin
      // Group srcb bits into triplets
      booth_triplet[pp_idx] = get_booth_triplet(pp_idx, srcb);

      // Get the partial products based on the encoded triplets
      booth_pp[pp_idx] = get_booth_pp(booth_triplet[pp_idx], srca, srca_comp2);

      // Get the sign of the partial products
      booth_pp_sign[pp_idx] = get_booth_pp_sign(booth_triplet[pp_idx], srca[SRCA_WIDTH-1]);
    end
  end

  // Sign-extend and shift the partial products according to their weight
  generate
    for (genvar pp_idx = 0; pp_idx < BOOTH_NUM_PP; pp_idx++) begin : gen_pp_shifted
      assign booth_pp_shifted[pp_idx] = {{(SRCB_WIDTH - (pp_idx * BOOTH_SHIFT_AMOUNT)){booth_pp_sign[pp_idx]}}, booth_pp[pp_idx][SRCA_WIDTH-1:0], {(pp_idx * BOOTH_SHIFT_AMOUNT){1'b0}}};
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
