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

  localparam int NUM_PP = SRC2_WIDTH;

  logic [NUM_PP-1:0][SRC1_WIDTH-1:0]   pp;
  logic [NUM_PP-1:0][RESULT_WIDTH-1:0] pp_shft;

  generate
    for (genvar b_i = 0; b_i < NUM_PP; b_i++) begin : gen_pp
      always_comb begin
        pp     [b_i] = srca & {SRC1_WIDTH{srcb[b_i]}};
        pp_shft[b_i] = {{(SRC2_WIDTH - b_i){1'b0}}, pp[b_i], {b_i{1'b0}}};
      end
    end : gen_pp
  endgenerate

  always_comb begin
    result = 0;
    for (int b_i = 0; b_i < NUM_PP; b_i++) begin
      result += pp_shft[b_i];
    end
  end

endmodule
