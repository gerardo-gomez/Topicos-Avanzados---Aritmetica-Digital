// Description: Array multiplier that handles signed numbers using Baugh-Wooley

module multiplier #(
  parameter  int SRC1_WIDTH   = 32,
  parameter  int SRC2_WIDTH   = SRC1_WIDTH,
  localparam int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH)
) (
  input  logic [SRC1_WIDTH-1:0]   srca,
  input  logic [SRC2_WIDTH-1:0]   srcb,
  input  logic                    is_signed,
  output logic [RESULT_WIDTH-1:0] result
);

  // Number of partial products
  localparam int NUM_NORMAL_PP = SRC2_WIDTH;                  // Number of normal partial products
  localparam int NUM_CORR_PP   = 1;                           // Number of correction partial products for Baugh-Wooley
  localparam int NUM_TOTAL_PP  = NUM_NORMAL_PP + NUM_CORR_PP; // Number of total partial products (normal + correction)

  // Partial products indexes
  localparam int LAST_NORMAL_PP_IDX = NUM_NORMAL_PP - 1;
  localparam int CORR_PP_IDX        = NUM_TOTAL_PP - 1;

  logic [NUM_NORMAL_PP-1:0][SRC1_WIDTH-1:0]   pp;
  logic [NUM_TOTAL_PP-1:0] [SRC1_WIDTH-1:0]   pp_mod;
  logic [NUM_TOTAL_PP-1:0] [RESULT_WIDTH-1:0] pp_shifted;

  always_comb begin
    // Normal partial products matrix
    for (int b_i = 0; b_i < NUM_NORMAL_PP; b_i++) begin
      pp[b_i] = srca & {SRC1_WIDTH{srcb[b_i]}};
    end

    // Baugh-Wooley modified partial products matrix
    // PPs with only one MSB are inverted
    for (int b_i = 0; b_i < LAST_NORMAL_PP_IDX; b_i++) begin
      pp_mod[b_i] = {~pp[b_i][SRC1_WIDTH-1], pp[b_i][SRC1_WIDTH-2:0]};
    end
    pp_mod[LAST_NORMAL_PP_IDX] = {pp[LAST_NORMAL_PP_IDX][SRC1_WIDTH-1], ~pp[LAST_NORMAL_PP_IDX][SRC1_WIDTH-2:0]};
    // Baugh-Wooley correction partial product
    pp_mod[CORR_PP_IDX] = {1'b1, {(SRC1_WIDTH-2){1'b0}}, 1'b1};
  end

  generate
    // Shift partial products according to their weight
    for (genvar b_i = 0; b_i < NUM_TOTAL_PP; b_i++) begin : gen_pp
      assign pp_shifted[b_i] = {{(SRC2_WIDTH - b_i){1'b0}}, pp_mod[b_i], {b_i{1'b0}}};
    end : gen_pp
  endgenerate

  always_comb begin
    // Accumulate sum of all partial products
    result = 0;
    for (int b_i = 0; b_i < NUM_TOTAL_PP; b_i++) begin
      result += pp_shifted[b_i];
    end
  end

endmodule
