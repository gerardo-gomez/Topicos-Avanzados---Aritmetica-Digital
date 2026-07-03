// Description: Wallace tree. Reduces N input operands to 2 output operands using 3:2 compressors (carry save adders).

module wallace_tree #(
    parameter  int WIDTH   = 32, // Width of the operands
    parameter  int NUM_IN  = 8,  // Number of input operands
    localparam int NUM_OUT = 2   // Number of output operands
) (
    input  logic [NUM_IN -1:0][WIDTH-1:0] in,
    output logic [NUM_OUT-1:0][WIDTH-1:0] out
);

  localparam int ADDER_WIDTH       = WIDTH;
  localparam int NUM_CSA_INPUTS    = 3;
  localparam int NUM_CSA_OUTPUTS   = 2;
  localparam int COMPRESS_RATIO    = NUM_CSA_OUTPUTS / NUM_CSA_INPUTS;

//// Function that returns the ceiling log base (3/2) of a given integer and that returns 1 as minimum value
//// This function is used to determine the number of CSA levels in the Wallace tree
//function automatic int clog3_2_min1(input int n);
//  if (n <= 1) return 1;
//  return int'($ceil($ln(n) / $ln(1.5)));
//endfunction

  // Function that determines the residual of n when divided by 3
  function automatic int f_get_remainder_3(input int n);
    return n % 3;
  endfunction

  // Function that determines if a number is a multiple of 3
  function automatic int f_is_mult_3(input int n);
    return f_get_remainder_3(n) == 0;
  endfunction

  // Function that determines if a CSA level will pass down an operand to the next level
  function automatic int f_lvl_passes_down_operand(input int n);
    return f_get_remainder_3(n) == 1;
  endfunction

  // Function that determines if a CSA level will use an auxiliary operand 0
  function automatic int f_lvl_uses_aux_operand(input int n);
    return f_get_remainder_3(n) == 2;
  endfunction

  // Function that adjusts the number of input operands to compress to a multiple of 3 in a CSA level
  // The adjustment depends on the remainder when dividing the number of remaining operands to compress by 3:
  // - If the remainder is 0, it means the number of operands is already a multiple of 3, so no adjustment is needed.
  // - If the remainder is 1, the remaining operand is passed down to the next level, and n is substracted by 1 to make it a multiple of 3.
  // - If the remainder is 2, an additional auxiliary operand 0 is added to make it a multiple of 3.
  function automatic int f_adjust_lvl_num_input_operands(input int n);
    if (f_is_mult_3(n))               return n;
    if (f_lvl_passes_down_operand(n)) return n - 1;
    if (f_lvl_uses_aux_operand(n))    return n + 1;
  endfunction

  // Function that determines the number of output operands / remaining operands to compress after the given CSA level
  // This function computes the number of operands per level iteratively until the specified level is reached
  function automatic int f_get_lvl_num_output_operands(input int lvl);
    int num_operands_left = NUM_IN;
    int lvl_input_num_operands;
    int lvl_output_num_operands;
    for (int lvl_iter = 0; lvl_iter <= lvl; lvl_iter++) begin
      lvl_input_num_operands  = f_adjust_lvl_num_input_operands(num_operands_left);
      lvl_output_num_operands = lvl_input_num_operands * COMPRESS_RATIO + f_lvl_passes_down_operand(num_operands_left);
      num_operands_left       = lvl_output_num_operands;
    end
    return lvl_output_num_operands;
  endfunction

  // Function that determines the number of input operands that a CSA level will compress
  function automatic int f_get_lvl_num_input_operands(input int lvl);
    if (lvl == 0) begin
      return f_adjust_lvl_num_input_operands(NUM_IN);
    end else begin
      return f_adjust_lvl_num_input_operands(f_get_lvl_num_output_operands(lvl-1));
    end
  endfunction

  // Function that determines the number of CSAs needed in each hierarchy level based on the number of operands left to compress
  function automatic int f_get_lvl_num_csa(input int lvl);
    return f_get_lvl_num_input_operands(lvl) / NUM_CSA_INPUTS;
  endfunction

  function automatic int f_get_num_csa_lvl();
    int num_operands_left = NUM_IN;
    int lvl = 0;
    while (num_operands_left > NUM_CSA_OUTPUTS) begin
      num_operands_left = f_get_lvl_num_output_operands(lvl);
      lvl++;
    end
    return lvl;
  endfunction

  function automatic int f_lvl_operand_to_csa_idx(input int operand_idx);
    return operand_idx / NUM_CSA_INPUTS;
  endfunction

  function automatic int f_lvl_operand_to_csa_input_idx(input int operand_idx);
    return operand_idx % NUM_CSA_INPUTS;
  endfunction

  localparam int NUM_CSA_LEVELS    = f_get_num_csa_lvl();
  localparam int MAX_CSA_PER_LEVEL = f_get_lvl_num_csa(0);
  localparam int FIRST_CSA_LEVEL   = 0;
  localparam int LAST_CSA_LEVEL    = NUM_CSA_LEVELS - 1;

  typedef logic [ADDER_WIDTH-1:0] t_operand;

  t_operand [NUM_IN-1:0]  tree_in;
  t_operand [NUM_OUT-1:0] tree_out;

  t_operand [NUM_CSA_LEVELS-1:0][MAX_CSA_PER_LEVEL-1:0][NUM_CSA_INPUTS-1:0]  csa_in;
  t_operand [NUM_CSA_LEVELS-1:0][MAX_CSA_PER_LEVEL-1:0][NUM_CSA_OUTPUTS-1:0] csa_out;

  t_operand [NUM_CSA_LEVELS-1:0][NUM_IN-1:0] lvl_input_operands;
  t_operand [NUM_CSA_LEVELS-1:0][NUM_IN-1:0] lvl_output_operands;

  genvar lvl;
  genvar operand_idx;

  // Wallace tree input / output assignments
  assign tree_in = in;
  assign out     = tree_out;

  // Wallace tree
  // CSA levels
  generate
    for (lvl = 0; lvl < NUM_CSA_LEVELS; lvl++) begin : gen_lvl
      localparam int NUM_REMAINING_OPERANDS  = (lvl == 0) ? NUM_IN : f_get_lvl_num_output_operands(lvl-1);
      localparam int NUM_INPUT_OPERANDS      = f_get_lvl_num_input_operands(lvl);
      localparam int NUM_OUTPUT_OPERANDS     = f_get_lvl_num_output_operands(lvl);
      localparam int LAST_INPUT_OPERAND_IDX  = NUM_INPUT_OPERANDS - 1;
      localparam int LAST_OUTPUT_OPERAND_IDX = NUM_OUTPUT_OPERANDS - 1;
      localparam int PASS_DOWN_OPERAND_IDX   = NUM_REMAINING_OPERANDS - 1;

      // CSA level input operand connections
      for (operand_idx = 0; operand_idx < NUM_INPUT_OPERANDS; operand_idx++) begin : gen_lvl_input

        if (lvl == FIRST_CSA_LEVEL) begin : gen_lvl0_input

          if ((operand_idx == LAST_INPUT_OPERAND_IDX) & (f_lvl_uses_aux_operand(NUM_REMAINING_OPERANDS))) begin : gen_lvl0_input_aux
            // Assign auxiliary operand 0 to the last position when applicable
            assign lvl_input_operands[lvl][operand_idx] = '0;

          end else begin : gen_lvl0_input_operand
            // Wire Wallace tree input operands to first CSA level operands
            assign lvl_input_operands[lvl][operand_idx] = tree_in[operand_idx];
          end : gen_lvl0_input_operand

        end else begin : gen_lvlN_input

          if ((operand_idx == LAST_INPUT_OPERAND_IDX) & (f_lvl_uses_aux_operand(NUM_REMAINING_OPERANDS))) begin : gen_lvlN_input_aux
            // Assign auxiliary operand 0 to the last position when applicable
            assign lvl_input_operands[lvl][operand_idx] = '0;

          end else begin : gen_lvlN_input_operand
            // Wire level input operands from output operands from previous level
            assign lvl_input_operands[lvl][operand_idx] = lvl_output_operands[lvl-1][operand_idx];
          end : gen_lvlN_input_operand

        end : gen_lvlN_input

        // Connect level input operands to the corresponding CSA input operands
        assign csa_in[lvl][f_lvl_operand_to_csa_idx(operand_idx)][f_lvl_operand_to_csa_input_idx(operand_idx)] = lvl_input_operands[lvl][operand_idx];
      end : gen_lvl_input

      // CSA level output operand connections
      for (operand_idx = 0; operand_idx < NUM_OUTPUT_OPERANDS; operand_idx++) begin : gen_lvl_output

        if ((operand_idx == LAST_OUTPUT_OPERAND_IDX) & (f_lvl_passes_down_operand(NUM_REMAINING_OPERANDS))) begin : gen_lvl_output_passdown
          // Pass down the last remaining operand to the next level when applicable
          assign lvl_output_operands[lvl][operand_idx] = lvl_input_operands[lvl][PASS_DOWN_OPERAND_IDX];

        end else begin : gen_lvl_output_operand
          // Wire CSA output operands to level output operands
          assign lvl_output_operands[lvl][operand_idx] = csa_out[lvl][f_lvl_operand_to_csa_idx(operand_idx)][f_lvl_operand_to_csa_input_idx(operand_idx)];
        end : gen_lvl_output_operand

      end : gen_lvl_output

    end : gen_lvl
  endgenerate

  // Wire Wallace tree output operands from last CSA level operands
  assign tree_out[0] = lvl_output_operands[LAST_CSA_LEVEL][0];
  assign tree_out[1] = lvl_output_operands[LAST_CSA_LEVEL][1];

endmodule
