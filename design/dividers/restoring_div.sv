// Description: Pipelined integer divider using restoring division algorithm

module divider#(
  parameter int WIDTH = 64
) (
  input  logic [WIDTH-1:0] srca,      // Dividend
  input  logic [WIDTH-1:0] srcb,      // Divisor
  input  logic             is_signed, // Indicates if the operation is signed(1) or unsigned(0)
  output logic [WIDTH-1:0] result,    // Quotient
  output logic [WIDTH-1:0] rem,       // Remainder
  output logic             div_zero_f // Divide-by-zero flag (asserted when srcb == 0)
);

  logic [WIDTH-1:0] a;          // Dividend
  logic [WIDTH-1:0] b;          // Divisor
  logic             a_sign;     // Dividend sign
  logic             b_sign;     // Divisor sign
  logic [WIDTH-1:0] a_comp1;    // Dividend one's complement
  logic [WIDTH-1:0] b_comp1;    // Divisor one's complement
  logic [WIDTH-1:0] a_comp2;    // Dividend two's complement
  logic [WIDTH-1:0] b_comp2;    // Divisor two's complement
  logic [WIDTH-1:0] a_abs;      // Dividend magnitude
//logic [WIDTH-1:0] b_abs;      // Divisor magnitude
  logic [WIDTH-1:0] b_neg;      // Divisor negated (two's complement) for subtraction
  logic [WIDTH  :0] b_neg_ext;  // Divisor negated (two's complement) for subtraction extended 1 bit for the trial subtraction

  // Iterative accumulators for the restoring algorithm
  logic [WIDTH:0][WIDTH:0]   rem_acc; // Partial remainder (extra bit for the left shift)
  logic [WIDTH:0][WIDTH-1:0] quo_acc; // Quotient being built (also holds the shifting dividend)

  logic [WIDTH-1:0] rem_abs;    // Remainder magnitude after algorithm iterations
  logic [WIDTH-1:0] quo_abs;    // Quotient magnitude after algorithm iterations
  logic [WIDTH-1:0] rem_comp1;  // Remainder one's complement
  logic [WIDTH-1:0] quo_comp1;  // Quotient one's complement
  logic [WIDTH-1:0] rem_comp2;  // Remainder two's complement
  logic [WIDTH-1:0] quo_comp2;  // Quotient two's complement

  // Extract signs and compute operand magnitudes.
  // Qualify signs with is_signed for unsigned operations
  always_comb begin
    a         = srca;
    b         = srcb;
    a_sign    = a[WIDTH-1] & is_signed;
    b_sign    = b[WIDTH-1] & is_signed;
    a_comp1   = ~a;
    b_comp1   = ~b;
    a_abs     = a_sign
              ? a_comp2
              : a;
//  b_abs     = b_sign
//            ? b_comp2
//            : b;
    b_neg     = b_sign
              ? b
              : b_comp2;
    b_neg_ext = {1'b1, b_neg};
  end

  // Source A two's complement: ~srca + 1
  adder #(
    .WIDTH(WIDTH)
  ) cla_srca_comp2 (
    .srca     (a_comp1  ),
    .srcb     (WIDTH'(1)),
    .cin      (1'b0     ),
    .is_signed(1'b0     ),
    .result   (a_comp2  ),
    .cout     (         ),
    .zero_f   (         ),
    .ov_f     (         )
  );

  // Source B two's complement: ~srcb + 1
  adder #(
    .WIDTH(WIDTH)
  ) cla_srcb_comp2 (
    .srca     (b_comp1  ),
    .srcb     (WIDTH'(1)),
    .cin      (1'b0     ),
    .is_signed(1'b0     ),
    .result   (b_comp2  ),
    .cout     (         ),
    .zero_f   (         ),
    .ov_f     (         )
  );

  // Restoring division on the magnitudes.
  // {rem_acc, quo_acc} is the combined shift register: the dividend starts in quo_acc
  // and the quotient bits are shifted into quo_acc[0] as the dividend leaves quo_acc[MSB].
  assign rem_acc[0] = '0;
  assign quo_acc[0] = a_abs;
  generate
    genvar i;
    for (i = 1; i <= WIDTH; i++) begin : gen_acc
      logic [WIDTH:0] rem_acc_pre_sub;  // Partial remainder before substraction
      logic [WIDTH:0] rem_acc_sub;      // Partial remainder subtraction trial
      logic           rem_acc_sub_sign; // Sign of the partial remainder after subtraction trial

      // Shift the {rem_acc, quo_acc} pair left by one, bringing the next dividend bit in
      assign quo_acc[i]       = {quo_acc[i-1][WIDTH-2:0], ~rem_acc_sub_sign};
      assign rem_acc_pre_sub  = {rem_acc[i-1][WIDTH-1:0], quo_acc[i-1][WIDTH-1]};

      // Substract the divisor from the partial remainder
      adder #(
        .WIDTH(WIDTH+1)
      ) cla_rem_acc_sub (
        .srca     (rem_acc_pre_sub), // Partial remainder before substraction
        .srcb     (b_neg_ext      ), // Divisor negated (two's complement) for subtraction
        .cin      (1'b0           ),
        .is_signed(1'b0           ),
        .result   (rem_acc_sub    ), // Partial remainder after substraction
        .cout     (               ),
        .zero_f   (               ),
        .ov_f     (               )
      );

      // Trial subtraction: only commit it when the divisor fits (otherwise restore = leave rem_acc)
      assign rem_acc_sub_sign = rem_acc_sub[WIDTH];
      assign rem_acc[i]       = rem_acc_sub_sign // Check sign of remainder after substraction
                              ? rem_acc_pre_sub  // If negative, restore the previous remainder
                              : rem_acc_sub;     // If positive, commit the subtraction result

    end : gen_acc
  endgenerate

  always_comb begin
    // Preeliminary quotient and remainder (magnitude) after algorithm iterations
    quo_abs   = quo_acc[WIDTH];
    rem_abs   = rem_acc[WIDTH][WIDTH-1:0];
    quo_comp1 = ~quo_abs;
    rem_comp1 = ~rem_abs;

    // Divide-by-zero detection
    div_zero_f = ~(|srcb);

    // Result override for divide-by-zero and sign correction for signed operations
    result = div_zero_f
           ? '1                          // On divide-by-zero the quotient is all-ones (-1 signed)
           : ( (a_sign ^ b_sign)
             ? quo_comp2                 // Quotient is negative when dividend and divisor signs differ
             : quo_abs);

    // Remainder override for divide-by-zero and sign correction for signed operations
    rem = div_zero_f
        ? a                              // On divide-by-zero the remainder is the dividend
        : ( a_sign                       // Remainder takes the sign of the dividend
          ? rem_comp2
          : rem_abs);
  end

  // Quotient two's complement: ~quo + 1
  adder #(
    .WIDTH(WIDTH)
  ) cla_quo_comp2 (
    .srca     (quo_comp1),
    .srcb     (WIDTH'(1)),
    .cin      (1'b0     ),
    .is_signed(1'b0     ),
    .result   (quo_comp2),
    .cout     (         ),
    .zero_f   (         ),
    .ov_f     (         )
  );

  // Remainder two's complement: ~rem + 1
  adder #(
    .WIDTH(WIDTH)
  ) cla_rem_comp2 (
    .srca     (rem_comp1),
    .srcb     (WIDTH'(1)),
    .cin      (1'b0     ),
    .is_signed(1'b0     ),
    .result   (rem_comp2),
    .cout     (         ),
    .zero_f   (         ),
    .ov_f     (         )
  );

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
