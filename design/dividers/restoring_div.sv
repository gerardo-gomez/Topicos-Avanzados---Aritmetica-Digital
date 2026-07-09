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

  // Signed operands are handled by dividing the magnitudes and correcting signs
  logic             a_sign;           // Dividend sign
  logic             b_sign;           // Divisor sign
  logic [WIDTH-1:0] abs_a;            // Dividend magnitude
  logic [WIDTH-1:0] abs_b;            // Divisor magnitude

  logic [WIDTH-1:0] uq;               // Unsigned (magnitude) quotient
  logic [WIDTH-1:0] ur;               // Unsigned (magnitude) remainder

  // Iterative accumulators for the restoring algorithm
  logic [WIDTH:0]   rem_acc;          // Partial remainder (extra bit for the left shift)
  logic [WIDTH-1:0] quo_acc;          // Quotient being built (also holds the shifting dividend)

  always_comb begin
    // Extract signs (only meaningful for signed operations) and compute operand magnitudes.
    // For unsigned operations the operands are used as-is (magnitude = operand).
    a_sign = srca[WIDTH-1] & is_signed;
    b_sign = srcb[WIDTH-1] & is_signed;
    abs_a  = a_sign ? (~srca + WIDTH'(1'b1)) : srca;
    abs_b  = b_sign ? (~srcb + WIDTH'(1'b1)) : srcb;

    // Restoring division on the magnitudes.
    // {rem_acc, quo_acc} is the combined shift register: the dividend starts in quo_acc
    // and the quotient bits are shifted into quo_acc[0] as the dividend leaves quo_acc[MSB].
    rem_acc = '0;
    quo_acc = abs_a;

    for (int i = 0; i < WIDTH; i++) begin
      // Shift the {rem_acc, quo_acc} pair left by one, bringing the next dividend bit in
      rem_acc = {rem_acc[WIDTH-1:0], quo_acc[WIDTH-1]};
      quo_acc = {quo_acc[WIDTH-2:0], 1'b0};

      // Trial subtraction: only commit it when the divisor fits (otherwise restore = leave rem_acc)
      if (rem_acc >= {1'b0, abs_b}) begin
        rem_acc    = rem_acc - {1'b0, abs_b};
        quo_acc[0] = 1'b1;
      end
    end

    uq = quo_acc;
    ur = rem_acc[WIDTH-1:0];

    // Divide-by-zero detection
    div_zero_f = (srcb == '0);

    if (div_zero_f) begin
      // On divide-by-zero the quotient is all-ones (-1 signed) and the remainder is the dividend
      result = '1;
      rem    = srca;
    end else begin
      // Sign correction:
      // - Quotient is negative when dividend and divisor signs differ
      // - Remainder takes the sign of the dividend (matches SystemVerilog % semantics)
      result = (a_sign ^ b_sign) ? (~uq + WIDTH'(1'b1)) : uq;
      rem    =  a_sign           ? (~ur + WIDTH'(1'b1)) : ur;
    end
  end

endmodule
