// Description: Pipelined integer divider using restoring division algorithm

module divider#(
  parameter int WIDTH = 64
) (
  input  logic             clk,

  input  logic [WIDTH-1:0] srca,      // Dividend
  input  logic [WIDTH-1:0] srcb,      // Divisor
  input  logic             is_signed, // Indicates if the operation is signed(1) or unsigned(0)
  output logic [WIDTH-1:0] result,    // Quotient
  output logic [WIDTH-1:0] rem,       // Remainder
  output logic             div_zero_f // Divide-by-zero flag (asserted when srcb == 0)
);

  localparam int NUM_RESTORING_STAGES       = WIDTH;
  localparam int NUM_TWOS_COMPLEMENT_STAGES = 2;

  // Pipeline naming convention: _s0 = stage 0, _s1 = stage 1, ..., _sn = stage N (last stage)
  //                             _ss = array of stages
  localparam int S0 = 0;
  localparam int S1 = 1;
  localparam int S2 = 2;
  localparam int SN = NUM_RESTORING_STAGES + NUM_TWOS_COMPLEMENT_STAGES - 1;

  logic [WIDTH-1:0] a_ss          [SN:S0];   // Dividend
  logic [WIDTH-1:0] b_s0;                    // Divisor
  logic             a_sign_ss     [SN:S0];   // Dividend sign
  logic             b_sign_ss     [SN:S0];   // Divisor sign
  logic [WIDTH-1:0] a_comp1_s0;              // Dividend one's complement
  logic [WIDTH-1:0] b_comp1_s0;              // Divisor one's complement
  logic [WIDTH-1:0] a_comp2_s0;              // Dividend two's complement
  logic [WIDTH-1:0] b_comp2_s0;              // Divisor two's complement
  logic [WIDTH-1:0] a_abs_s0;                // Dividend magnitude
  logic [WIDTH-1:0] a_abs_s1;                // Dividend magnitude
//logic [WIDTH-1:0] b_abs_s0;                // Divisor magnitude
  logic [WIDTH-1:0] b_neg_ss      [SN-1:S0]; // Divisor with negative sign to use as subtrahend
  logic             div_zero_f_ss [SN:SN-1]; // Divide-by-zero flag

  // Iterative accumulators for the restoring algorithm
  logic [WIDTH:0]   rem_acc_ss     [SN:S2];  // Partial remainder (extra bit for the left shift)
  logic [WIDTH-1:0] quo_acc_ss     [SN:S2];  // Quotient being built (also holds the shifting dividend)
  logic [WIDTH:0]   rem_acc_nxt_ss [SN-1:S1];
  logic [WIDTH-1:0] quo_acc_nxt_ss [SN-1:S1];

  logic [WIDTH-1:0] rem_abs_sn;    // Remainder magnitude after algorithm iterations
  logic [WIDTH-1:0] quo_abs_sn;    // Quotient magnitude after algorithm iterations
  logic [WIDTH-1:0] rem_comp1_sn;  // Remainder one's complement
  logic [WIDTH-1:0] quo_comp1_sn;  // Quotient one's complement
  logic [WIDTH-1:0] rem_comp2_sn;  // Remainder two's complement
  logic [WIDTH-1:0] quo_comp2_sn;  // Quotient two's complement

  genvar stage;

  /////////////////////////////////////////////////////////////////
  // Stage 0: Input assignments and get operands absolute values
  /////////////////////////////////////////////////////////////////

  // Extract operands signs
  // Qualify signs with is_signed for unsigned operations
  assign a_ss[S0]      = srca;
  assign b_s0          = srcb;
  assign a_sign_ss[S0] = srca[WIDTH-1] & is_signed;
  assign b_sign_ss[S0] = srcb[WIDTH-1] & is_signed;

  // Source A and B one's complement
  assign a_comp1_s0 = ~srca;
  assign b_comp1_s0 = ~srcb;

  // Source A two's complement: ~srca + 1
  adder #(
    .WIDTH(WIDTH)
  ) cla_srca_comp2 (
    .srca     (a_comp1_s0),
    .srcb     (WIDTH'(1) ),
    .cin      (1'b0      ),
    .is_signed(1'b0      ),
    .result   (a_comp2_s0),
    .cout     (          ),
    .zero_f   (          ),
    .ov_f     (          )
  );

  // Source B two's complement: ~srcb + 1
  adder #(
    .WIDTH(WIDTH)
  ) cla_srcb_comp2 (
    .srca     (b_comp1_s0),
    .srcb     (WIDTH'(1) ),
    .cin      (1'b0      ),
    .is_signed(1'b0      ),
    .result   (b_comp2_s0),
    .cout     (          ),
    .zero_f   (          ),
    .ov_f     (          )
  );

  // Compute dividend magnitude and divisor with negative sign to use as subtrahend
  assign a_abs_s0    = a_sign_ss[S0]
                     ? a_comp2_s0
                     : a_ss[S0];
//assign b_abs_s0    = b_sign_ss[S0]
//                   ? b_comp2_s0
//                   : b_s0;
  assign b_neg_ss[S0] = b_sign_ss[S0]
                      ? b_s0
                      : b_comp2_s0;

  /////////////////////////////////////////////////////////////////
  // Stage 1 to N-1: Iterative restoring division algorithm
  /////////////////////////////////////////////////////////////////

  // Restoring division on the magnitudes.
  // {rem_acc, quo_acc} is the combined shift register: the dividend starts in quo_acc
  // and the quotient bits are shifted into quo_acc[0] as the dividend leaves quo_acc[MSB].
  generate
    for (stage = S1; stage < (NUM_RESTORING_STAGES + S1); stage++) begin : gen_restoring_div
      logic [WIDTH:0]   b_neg_ext;         // Divisor with negative sign to use as subtrahend (extended 1 bit to match rem_acc width)
      logic [WIDTH:0]   rem_acc_pre_shift; // Partial remainder from previous iteration
      logic [WIDTH:0]   rem_acc_pre_sub;   // Partial remainder before substraction
      logic [WIDTH:0]   rem_acc_sub;       // Partial remainder subtraction trial
      logic             rem_acc_sub_sign;  // Sign of the partial remainder after subtraction trial
      logic [WIDTH-1:0] quo_acc_pre_shift; // Quotient being built (also holds the shifting dividend) from previous iteration
      logic [WIDTH-1:0] quo_acc;           // Quotient being built (also holds the shifting dividend)

      if (stage == 1) begin
      // Initialize {rem_acc, quo_acc} = A (dividend)
        assign rem_acc_pre_shift = '0;
        assign quo_acc_pre_shift = a_abs_s1;
      end else begin
        assign rem_acc_pre_shift = rem_acc_ss[stage];
        assign quo_acc_pre_shift = quo_acc_ss[stage];
      end

      // Shift the {rem_acc, quo_acc} pair left by one, bringing the next dividend bit in
      assign quo_acc         = {quo_acc_pre_shift[WIDTH-2:0], 1'b0};
      assign rem_acc_pre_sub = {rem_acc_pre_shift[WIDTH-1:0], quo_acc_pre_shift[WIDTH-1]};

      // Substract the divisor from the partial remainder
      adder #(
        .WIDTH(WIDTH+1)
      ) cla_rem_acc_sub (
        .srca     (rem_acc_pre_sub), // Partial remainder before substraction
        .srcb     (b_neg_ext      ), // Divisor with negative sign to use as subtrahend
        .cin      (1'b0           ),
        .is_signed(1'b0           ),
        .result   (rem_acc_sub    ), // Partial remainder after substraction
        .cout     (               ),
        .zero_f   (               ),
        .ov_f     (               )
      );

      assign b_neg_ext        = {1'b1, b_neg_ss[stage]};
      assign rem_acc_sub_sign = rem_acc_sub[WIDTH];

      // Trial subtraction: only commit it when the divisor fits (otherwise restore = leave rem_acc)
      assign rem_acc_nxt_ss[stage] = rem_acc_sub_sign                         // Check sign of remainder after substraction
                                   ? rem_acc_pre_sub                          // If negative, restore the previous remainder
                                   : rem_acc_sub;                             // If positive, commit the subtraction result
      assign quo_acc_nxt_ss[stage] = {quo_acc[WIDTH-1:1], ~rem_acc_sub_sign}; // If negative issue 0 in the quotient LSB
                                                                              // If positive issue 1 in the quotient LSB
    end : gen_restoring_div
  endgenerate

  /////////////////////////////////////////////////////////////////
  // Stage N-1: Divide-by-zero detection
  /////////////////////////////////////////////////////////////////

  assign div_zero_f_ss[SN-1] = ~(|b_neg_ss[SN-1]); // Last stage where the divisor is available to check for divide-by-zero

  /////////////////////////////////////////////////////////////////
  // Stage N: Apply sign to result and output assignments
  /////////////////////////////////////////////////////////////////

  // Preeliminary quotient and remainder magnitudes after algorithm iterations
  assign quo_abs_sn = quo_acc_ss[SN];
  assign rem_abs_sn = rem_acc_ss[SN][WIDTH-1:0];

  // Quotient and remainder one's complement
  assign quo_comp1_sn = ~quo_abs_sn;
  assign rem_comp1_sn = ~rem_abs_sn;

  // Quotient two's complement: ~quo + 1
  adder #(
    .WIDTH(WIDTH)
  ) cla_quo_comp2 (
    .srca     (quo_comp1_sn),
    .srcb     (WIDTH'(1)   ),
    .cin      (1'b0        ),
    .is_signed(1'b0        ),
    .result   (quo_comp2_sn),
    .cout     (            ),
    .zero_f   (            ),
    .ov_f     (            )
  );

  // Remainder two's complement: ~rem + 1
  adder #(
    .WIDTH(WIDTH)
  ) cla_rem_comp2 (
    .srca     (rem_comp1_sn),
    .srcb     (WIDTH'(1)   ),
    .cin      (1'b0        ),
    .is_signed(1'b0        ),
    .result   (rem_comp2_sn),
    .cout     (            ),
    .zero_f   (            ),
    .ov_f     (            )
  );

  // Result override for divide-by-zero and sign correction for signed operations
  assign result = div_zero_f_ss[SN]
                ? '1                                // On divide-by-zero the quotient is all-ones (-1 signed)
                : ( (a_sign_ss[SN] ^ b_sign_ss[SN])
                  ? quo_comp2_sn                    // Quotient is negative when dividend and divisor signs differ
                  : quo_abs_sn);

  // Remainder override for divide-by-zero and sign correction for signed operations
  assign rem = div_zero_f_ss[SN]
             ? a_ss[SN]          // On divide-by-zero the remainder is the dividend
             : ( a_sign_ss[SN]   // Remainder takes the sign of the dividend
               ? rem_comp2_sn
               : rem_abs_sn);

  // Divide-by-zero output assignment
  assign div_zero_f = div_zero_f_ss[SN];

  /////////////////////////////////////////////////////////////////
  // Flop pipe stages
  /////////////////////////////////////////////////////////////////

  always_ff @(posedge clk) begin
    a_abs_s1          <= a_abs_s0;
    div_zero_f_ss[SN] <= div_zero_f_ss[SN-1];
  end

  generate
    for (stage = S1; stage <= SN; stage++) begin : gen_staging_1
      always_ff @(posedge clk) begin
        a_ss     [stage] <= a_ss     [stage-1];
        b_neg_ss [stage] <= b_neg_ss [stage-1];
        a_sign_ss[stage] <= a_sign_ss[stage-1];
        b_sign_ss[stage] <= b_sign_ss[stage-1];
      end
    end : gen_staging_1

    for (stage = S2; stage <= SN; stage++) begin : gen_staging_2
      always_ff @(posedge clk) begin
        rem_acc_ss[stage] <= rem_acc_nxt_ss[stage-1];
        quo_acc_ss[stage] <= quo_acc_nxt_ss[stage-1];
      end
    end : gen_staging_2
  endgenerate

endmodule

// Single-cycle restoring divider
//module divider#(
//  parameter int WIDTH = 64
//) (
//  input  logic [WIDTH-1:0] srca,      // Dividend
//  input  logic [WIDTH-1:0] srcb,      // Divisor
//  input  logic             is_signed, // Indicates if the operation is signed(1) or unsigned(0)
//  output logic [WIDTH-1:0] result,    // Quotient
//  output logic [WIDTH-1:0] rem,       // Remainder
//  output logic             div_zero_f // Divide-by-zero flag (asserted when srcb == 0)
//);
//
//  logic             a_sign;     // Dividend sign
//  logic             b_sign;     // Divisor sign
//  logic [WIDTH-1:0] a_abs;      // Dividend magnitude
//  logic [WIDTH-1:0] b_abs;      // Divisor magnitude
//
//  // Iterative accumulators for the restoring algorithm
//  logic [WIDTH:0]   rem_sub;    // Partial remainder subtraction trial
//  logic [WIDTH:0]   rem_acc;    // Partial remainder (extra bit for the left shift)
//  logic [WIDTH-1:0] quo_acc;    // Quotient being built (also holds the shifting dividend)
//
//  logic [WIDTH-1:0] rem_abs;    // Remainder magnitude after algorithm iterations
//  logic [WIDTH-1:0] quo_abs;    // Quotient magnitude after algorithm iterations
//
//  always_comb begin
//    // Extract signs and compute operand magnitudes.
//    // Qualify signs with is_signed for unsigned operations
//    a_sign = srca[WIDTH-1] & is_signed;
//    b_sign = srcb[WIDTH-1] & is_signed;
//    a_abs  = a_sign
//           ? (~srca + WIDTH'(1'b1))
//           : srca;
//    b_abs  = b_sign
//           ? (~srcb + WIDTH'(1'b1))
//           : srcb;
//
//    // Restoring division on the magnitudes.
//    // {rem_acc, quo_acc} is the combined shift register: the dividend starts in quo_acc
//    // and the quotient bits are shifted into quo_acc[0] as the dividend leaves quo_acc[MSB].
//    rem_acc = '0;
//    quo_acc = a_abs;
//
//    for (int i = 0; i < WIDTH; i++) begin
//      // Shift the {rem_acc, quo_acc} pair left by one, bringing the next dividend bit in
//      rem_acc = {rem_acc[WIDTH-1:0], quo_acc[WIDTH-1]};
//      quo_acc = {quo_acc[WIDTH-2:0], 1'b0};
//
//      // Trial subtraction: only commit it when the divisor fits (otherwise restore = leave rem_acc)
//      rem_sub    = rem_acc - {1'b0, b_abs};
//      rem_acc    = rem_sub[WIDTH]
//                 ? rem_acc
//                 : rem_sub;
//      quo_acc[0] = ~rem_sub[WIDTH];
//    end
//
//    // Preeliminary quotient and remainder (magnitude) after algorithm iterations
//    quo_abs = quo_acc;
//    rem_abs = rem_acc[WIDTH-1:0];
//
//    // Divide-by-zero detection
//    div_zero_f = ~(|srcb);
//
//    // Result override for divide-by-zero and sign correction for signed operations
//    result = div_zero_f
//           ? '1                          // On divide-by-zero the quotient is all-ones (-1 signed)
//           : ( (a_sign ^ b_sign)
//             ? (~quo_abs + WIDTH'(1'b1)) // Quotient is negative when dividend and divisor signs differ
//             : quo_abs);
//
//    // Remainder override for divide-by-zero and sign correction for signed operations
//    rem = div_zero_f
//        ? srca                           // On divide-by-zero the remainder is the dividend
//        : ( a_sign                       // Remainder takes the sign of the dividend
//          ? (~rem_abs + WIDTH'(1'b1))
//          : rem_abs);
//  end
//
//endmodule
