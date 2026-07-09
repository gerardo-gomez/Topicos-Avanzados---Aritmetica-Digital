// Description: Integer divider module using restoring division algorithm

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

  logic             a_sign;     // Dividend sign
  logic             b_sign;     // Divisor sign
  logic [WIDTH-1:0] a_abs;      // Dividend magnitude
  logic [WIDTH-1:0] b_abs;      // Divisor magnitude

  // Iterative accumulators for the restoring algorithm
  logic [WIDTH:0]   rem_sub;    // Partial remainder subtraction trial
  logic [WIDTH:0]   rem_acc;    // Partial remainder (extra bit for the left shift)
  logic [WIDTH-1:0] quo_acc;    // Quotient being built (also holds the shifting dividend)

  logic [WIDTH-1:0] rem_abs;    // Remainder magnitude after algorithm iterations
  logic [WIDTH-1:0] quo_abs;    // Quotient magnitude after algorithm iterations

  always_comb begin
    // Extract signs and compute operand magnitudes.
    // Qualify signs with is_signed for unsigned operations
    a_sign = srca[WIDTH-1] & is_signed;
    b_sign = srcb[WIDTH-1] & is_signed;
    a_abs  = a_sign
           ? (~srca + WIDTH'(1'b1))
           : srca;
    b_abs  = b_sign
           ? (~srcb + WIDTH'(1'b1))
           : srcb;

    // Restoring division on the magnitudes.
    // {rem_acc, quo_acc} is the combined shift register: the dividend starts in quo_acc
    // and the quotient bits are shifted into quo_acc[0] as the dividend leaves quo_acc[MSB].
    rem_acc = '0;
    quo_acc = a_abs;

    for (int i = 0; i < WIDTH; i++) begin
      // Shift the {rem_acc, quo_acc} pair left by one, bringing the next dividend bit in
      rem_acc = {rem_acc[WIDTH-1:0], quo_acc[WIDTH-1]};
      quo_acc = {quo_acc[WIDTH-2:0], 1'b0};

      // Trial subtraction: only commit it when the divisor fits (otherwise restore = leave rem_acc)
      rem_sub    = rem_acc - {1'b0, b_abs};
      rem_acc    = rem_sub[WIDTH]
                 ? rem_acc
                 : rem_sub;
      quo_acc[0] = ~rem_sub[WIDTH];
    end

    // Preeliminary quotient and remainder (magnitude) after algorithm iterations
    quo_abs = quo_acc;
    rem_abs = rem_acc[WIDTH-1:0];

    // Divide-by-zero detection
    div_zero_f = ~(|srcb);

    // Result override for divide-by-zero and sign correction for signed operations
    result = div_zero_f
           ? '1                          // On divide-by-zero the quotient is all-ones (-1 signed)
           : ( (a_sign ^ b_sign)
             ? (~quo_abs + WIDTH'(1'b1)) // Quotient is negative when dividend and divisor signs differ
             : quo_abs);

    // Remainder override for divide-by-zero and sign correction for signed operations
    rem = div_zero_f
        ? srca                           // On divide-by-zero the remainder is the dividend
        : ( a_sign                       // Remainder takes the sign of the dividend
          ? (~rem_abs + WIDTH'(1'b1))
          : rem_abs);
  end

endmodule
