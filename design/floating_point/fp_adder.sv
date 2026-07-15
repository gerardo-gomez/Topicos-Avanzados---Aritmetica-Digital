// Description: Half precision (16-bits) floating point adder/subtractor (IEEE 754 binary16) coded by Claude
//   op: 0 = add (a + b), 1 = sub (a - b, implemented as a + (-b))
//   Format: [15] sign, [14:10] exponent (bias 15), [9:0] fraction (10 bits, implicit leading 1 for normals)
//   Rounding modes (rm): RNE=0, RTZ=1, RDN=2, RUP=3, RMM=4
//   fflags = {NV, DZ, OF, UF, NX}  (DZ is always 0 for add)

module fp_adder (
  input  logic [15:0] srca,
  input  logic [15:0] srcb,
  input  logic        op,      // 0 = add, 1 = sub
  input  logic [2:0]  rm,      // modo de redondeo   RNE=0, RTZ=1, RDN=2, RUP=3, RMM=4
  output logic [15:0] result,
  output logic [4:0]  fflags   // {NV, DZ, OF, UF, NX}
);

  // Rounding modes
  localparam logic [2:0] RNE = 3'd0;
  localparam logic [2:0] RTZ = 3'd1;
  localparam logic [2:0] RDN = 3'd2;
  localparam logic [2:0] RUP = 3'd3;
  localparam logic [2:0] RMM = 3'd4;

  // Canonical special encodings
  localparam logic [15:0] QNAN16 = 16'h7E00; // canonical quiet NaN

  // Count leading zeros over a 42-bit vector (returns 42 if all zero)
  function automatic int f_clz42(input logic [41:0] v);
    f_clz42 = 42;
    for (int i = 41; i >= 0; i--) begin
      if (v[i]) begin
        f_clz42 = 41 - i;
        break;
      end
    end
  endfunction

  // NaN propagation, matching Berkeley SoftFloat softfloat_propagateNaNF16UI (8086/default):
  // propagate an input NaN with the quiet bit set (payload preserved); pick larger magnitude on ties.
  function automatic logic [15:0] f_propagate_nan(input logic [15:0] uiA, input logic [15:0] uiB);
    logic        is_nan_a, is_nan_b, is_snan_a, is_snan_b;
    logic [15:0] nA, nB, larger;
    logic [14:0] magA, magB;
    is_nan_a  = (uiA[14:10] == 5'h1F) && (uiA[9:0] != 10'd0);
    is_nan_b  = (uiB[14:10] == 5'h1F) && (uiB[9:0] != 10'd0);
    is_snan_a = is_nan_a && ~uiA[9];
    is_snan_b = is_nan_b && ~uiB[9];
    nA   = uiA | 16'h0200;        // quiet the NaN
    nB   = uiB | 16'h0200;
    magA = uiA[14:0];
    magB = uiB[14:0];
    larger = (magA < magB) ? nB : (magB < magA) ? nA : ((uiA < uiB) ? nA : nB);
    if (is_snan_a || is_snan_b) begin
      if (is_snan_a) f_propagate_nan = is_snan_b ? larger : (is_nan_b ? nB : nA);
      else           f_propagate_nan = is_nan_a ? nA : nB;
    end
    else begin
      f_propagate_nan = larger;
    end
  endfunction

  always_comb begin
    // ---------------------------------------------------------------------
    // Unpack operands
    // ---------------------------------------------------------------------
    logic        sa, sb;
    logic [4:0]  ea, eb;
    logic [9:0]  ma, mb;

    logic        a_zero, a_inf, a_nan, a_snan;
    logic        b_zero, b_inf, b_nan, b_snan;

    logic [10:0] sig_a, sig_b;     // significand with implicit bit (11 bits)
    int          ea_eff, eb_eff;   // effective (biased) exponent, subnormal mapped to 1

    // Arithmetic-path signals
    logic        a_ge;
    logic [10:0] big_sig, small_sig;
    int          e_big, e_small, diff;
    logic        sign_big, sign_small, sign_res, eff_sub;
    logic [41:0] big_ext, small_ext, S, norm;
    int          lead, e_out_tent, rsh;
    logic [41:0] shifted, stick_mask;
    logic [10:0] sig11;
    logic        guard, sticky, lsb, round_up, inexact;
    logic [11:0] sig_r;
    int          e_field;
    logic [9:0]  mant;
    logic        overflow, subnormal_res;
    logic [15:0] of_res;

    sa = srca[15];        ea = srca[14:10]; ma = srca[9:0];
    sb = srcb[15] ^ op;   eb = srcb[14:10]; mb = srcb[9:0]; // op=1 (sub): a - b = a + (-b), only b's sign flips

    a_zero = (ea == 5'd0)  && (ma == 10'd0);
    a_inf  = (ea == 5'd31) && (ma == 10'd0);
    a_nan  = (ea == 5'd31) && (ma != 10'd0);
    a_snan = a_nan && ~ma[9];

    b_zero = (eb == 5'd0)  && (mb == 10'd0);
    b_inf  = (eb == 5'd31) && (mb == 10'd0);
    b_nan  = (eb == 5'd31) && (mb != 10'd0);
    b_snan = b_nan && ~mb[9];

    sig_a  = (ea == 5'd0) ? {1'b0, ma} : {1'b1, ma};
    sig_b  = (eb == 5'd0) ? {1'b0, mb} : {1'b1, mb};
    ea_eff = (ea == 5'd0) ? 1 : int'(ea);
    eb_eff = (eb == 5'd0) ? 1 : int'(eb);

    // Defaults
    result = 16'h0000;
    fflags = 5'b00000;

    // Placeholders (assigned in arithmetic branch, initialized to avoid latches)
    a_ge = 1'b0; big_sig = '0; small_sig = '0; e_big = 0; e_small = 0; diff = 0;
    sign_big = 1'b0; sign_small = 1'b0; sign_res = 1'b0; eff_sub = 1'b0;
    big_ext = '0; small_ext = '0; S = '0; norm = '0;
    lead = 0; e_out_tent = 0; rsh = 0; shifted = '0; stick_mask = '0;
    sig11 = '0; guard = 1'b0; sticky = 1'b0; lsb = 1'b0; round_up = 1'b0; inexact = 1'b0;
    sig_r = '0; e_field = 0; mant = '0; overflow = 1'b0; subnormal_res = 1'b0; of_res = '0;

    // ---------------------------------------------------------------------
    // Special cases
    // ---------------------------------------------------------------------
    if (a_nan || b_nan) begin
      // A NaN operand propagates (payload preserved, quieted) per SoftFloat
      result    = f_propagate_nan(srca, srcb);
      fflags[4] = a_snan | b_snan;                  // NV set only for signaling NaN
    end
    else if (a_inf && b_inf && (sa != sb)) begin
      // Inf - Inf is invalid -> generated (default) canonical qNaN
      result    = QNAN16;
      fflags[4] = 1'b1;                             // NV
    end
    else if (a_inf || b_inf) begin
      // Infinity dominates (same-sign inf, or inf + finite)
      result = a_inf ? {sa, 5'd31, 10'd0} : {sb, 5'd31, 10'd0};
    end
    else if (a_zero && b_zero) begin
      // Both zero: same sign keeps it; opposite signs -> +0, except round-down -> -0
      result = {(sa == sb) ? sa : (rm == RDN), 15'd0};
    end
    else if (a_zero) begin
      result = {srcb[15] ^ op, srcb[14:0]}; // exact: 0 + b = b, 0 - b = -b
    end
    else if (b_zero) begin
      result = srca; // exact
    end
    else begin
      // -----------------------------------------------------------------
      // General finite + finite path
      // -----------------------------------------------------------------
      // Pick the operand with the larger magnitude as "big"
      a_ge = (ea_eff > eb_eff) || ((ea_eff == eb_eff) && (sig_a >= sig_b));

      big_sig    = a_ge ? sig_a  : sig_b;
      small_sig  = a_ge ? sig_b  : sig_a;
      e_big      = a_ge ? ea_eff : eb_eff;
      e_small    = a_ge ? eb_eff : ea_eff;
      sign_big   = a_ge ? sa     : sb;
      sign_small = a_ge ? sb     : sa;
      diff       = e_big - e_small;           // 0..29
      eff_sub    = sign_big ^ sign_small;

      // Exact alignment: 11-bit significand + 29 low bits captures any shift (diff <= 29)
      big_ext   = {31'd0, big_sig}   << 29;
      small_ext = ({31'd0, small_sig} << 29) >> $unsigned(diff);

      S        = eff_sub ? (big_ext - small_ext) : (big_ext + small_ext);
      sign_res = sign_big;

      if (S == 42'd0) begin
        // Exact cancellation -> signed zero (per rounding mode)
        result = {(rm == RDN), 15'd0};
      end
      else begin
        // Normalize: bring MSB of S to bit 41
        lead       = f_clz42(S);
        norm       = S << $unsigned(lead);
        e_out_tent = e_big + 2 - lead;        // tentative biased exponent (normalized)

        // Right shift to extract the 11-bit significand (subnormals shift further)
        rsh = (e_out_tent < 1) ? (31 + (1 - e_out_tent)) : 31;

        if (rsh > 42) begin
          // Deep underflow: everything becomes sticky
          sig11  = 11'd0;
          guard  = 1'b0;
          sticky = 1'b1;
        end
        else begin
          shifted    = norm >> $unsigned(rsh);
          sig11      = shifted[10:0];
          guard      = norm[rsh-1];
          stick_mask = (rsh <= 1) ? 42'd0 : ((42'd1 << $unsigned(rsh-1)) - 42'd1);
          sticky     = |(norm & stick_mask);
        end

        // Rounding decision
        lsb     = sig11[0];
        unique case (rm)
          RNE:     round_up = guard & (sticky | lsb);
          RTZ:     round_up = 1'b0;
          RDN:     round_up = sign_res & (guard | sticky);
          RUP:     round_up = ~sign_res & (guard | sticky);
          RMM:     round_up = guard;                     // nearest, ties away from zero
          default: round_up = guard & (sticky | lsb);
        endcase

        inexact = guard | sticky;
        sig_r   = {1'b0, sig11} + {11'd0, round_up};

        subnormal_res = (e_out_tent < 1);

        if (!subnormal_res) begin
          // Normal path
          if (sig_r[11]) begin
            // Rounding carried out -> renormalize (significand back to 1.0)
            e_field = e_out_tent + 1;
            mant    = 10'd0;
          end
          else begin
            e_field = e_out_tent;
            mant    = sig_r[9:0];
          end

          if (e_field >= 31) begin
            overflow = 1'b1;
          end
        end
        else begin
          // Subnormal path (rounding may promote to smallest normal)
          if (sig_r[10]) begin
            e_field = 1;             // promoted to smallest normal
            mant    = sig_r[9:0];    // == 0
          end
          else begin
            e_field = 0;             // subnormal
            mant    = sig_r[9:0];
          end
        end

        // -------------------------------------------------------------
        // Assemble result and flags
        // -------------------------------------------------------------
        if (overflow) begin
          // Overflow -> inf or max finite depending on rounding mode
          unique case (rm)
            RTZ:     of_res = {sign_res, 5'd30, 10'h3FF}; // toward zero -> max finite
            RDN:     of_res = sign_res ? {sign_res, 5'd31, 10'd0} : {sign_res, 5'd30, 10'h3FF};
            RUP:     of_res = sign_res ? {sign_res, 5'd30, 10'h3FF} : {sign_res, 5'd31, 10'd0};
            default: of_res = {sign_res, 5'd31, 10'd0};   // RNE, RMM -> inf
          endcase
          result    = of_res;
          fflags[2] = 1'b1;         // OF
          fflags[0] = 1'b1;         // NX
        end
        else begin
          result    = {sign_res, e_field[4:0], mant};
          fflags[1] = (e_field == 0) & inexact;  // UF: subnormal & inexact
          fflags[0] = inexact;                   // NX
        end
      end
    end
  end

endmodule
