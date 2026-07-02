// Description: Array multiplier that handles signed numbers using Baugh-Wooley and adds partial products in cascade (TODO: add them using CSA and CPA)

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

  // The number of partial products (PP) is determined by SRCB_WIDTH, and each PP has a width of SRCA_WIDTH
  logic [SRCB_WIDTH-1:0][SRCA_WIDTH-1:0]   pp_unsigned;
  logic [SRCB_WIDTH-1:0][SRCA_WIDTH-1:0]   pp_signed;
  logic [SRCB_WIDTH-1:0][SRCA_WIDTH-1:0]   pp;
  logic [SRCB_WIDTH-1:0][RESULT_WIDTH-1:0] pp_shifted;
  logic                 [RESULT_WIDTH-1:0] signed_corr;

  // Regular partial products matrix
  always_comb begin
    for (int b_i = 0; b_i < SRCB_WIDTH; b_i++) begin
      pp_unsigned[b_i] = srca & {SRCA_WIDTH{srcb[b_i]}};
    end
  end

  // Baugh-Wooley modified partial products matrix
  always_comb begin
    // PPs with no MSB or both MSBs are not inverted (default)
    pp_signed = pp_unsigned;
    // PPs with only SRCA[MSB] are inverted
    for (int b_i = 0; b_i < (SRCB_WIDTH-1); b_i++) begin
      pp_signed[b_i][SRCA_WIDTH-1] = ~pp_unsigned[b_i][SRCA_WIDTH-1];
    end
    // PPs with only SRCB[MSB] are inverted
    for (int a_i = 0; a_i < (SRCA_WIDTH-1); a_i++) begin
      pp_signed[SRCB_WIDTH-1][a_i] = ~pp_unsigned[SRCB_WIDTH-1][a_i];
    end

    // Constant correction bits
    // These constant 1 bits are injected before the partial product addition.
    // When n != m (asymetric case), the 3 correction bit positions are: n-1, m-1 and n+m-1
    // When n  = m (symetric case), the 2 correction bit positions are: n and 2n-1
    // To handle both cases, computing the constant correction with arithmetic addition is done
    // so equal-position terms accumulate / carry to position n for the symmetric case, while the
    // asymetric case still gets the independent n-1 and m-1 (and n+m-1) positions.
    signed_corr = is_signed
                ? ( (RESULT_WIDTH'(1'b1) << (SRCA_WIDTH-1))
                  + (RESULT_WIDTH'(1'b1) << (SRCB_WIDTH-1))
                  + (RESULT_WIDTH'(1'b1) << (RESULT_WIDTH-1)))
                : '0;
  end

  // Select between unsigned and signed partial products
  assign pp = is_signed
            ? pp_signed
            : pp_unsigned;

  // Shift partial products according to their weight
  generate
    for (genvar b_i = 0; b_i < SRCB_WIDTH; b_i++) begin : gen_pp_shifted
      assign pp_shifted[b_i] = {{(SRCB_WIDTH - b_i){1'b0}}, pp[b_i], {b_i{1'b0}}};
    end : gen_pp_shifted
  endgenerate

  // Sum of all partial products
  always_comb begin
    result = 0;
    for (int b_i = 0; b_i < SRCB_WIDTH; b_i++) begin
      result += pp_shifted[b_i];
    end
    // Add the constant correction bits for signed multiplication
    result += signed_corr;
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
