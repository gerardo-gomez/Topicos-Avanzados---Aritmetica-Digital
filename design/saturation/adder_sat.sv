// Description: N-bits Adder with saturation

module adder_sat#(
  parameter int WIDTH = 32
) (
  input  logic [WIDTH-1:0] srca,
  input  logic [WIDTH-1:0] srcb,
  input  logic             sat_to_max,    // Indicates if saturate to max value is enabled
  input  logic [WIDTH-1:0] max_sat_value, // Max value to saturate result, should be > min_sat_value
  input  logic             sat_to_min,    // Indicates if saturate to min value is enabled
  input  logic [WIDTH-1:0] min_sat_value, // Min value to saturate result, should be < max_sat_value
  input  logic             cin,
  input  logic             is_signed,
  output logic [WIDTH-1:0] result
);

  logic [(WIDTH + 1)-1:0] ext_srca;                // Extended source A
  logic [(WIDTH + 1)-1:0] ext_srcb;                // Extended source B
  logic [ WIDTH     -1:0] result_pre_sat;          // Result from adder adjusted to WIDTH bits
  logic [(WIDTH + 1)-1:0] ext_result_pre_sat;      // Extended result
  logic [(WIDTH + 1)-1:0] ext_min_sat_value;       // Extended min saturation value
  logic [(WIDTH + 1)-1:0] ext_max_sat_value;       // Extended max saturation value
  logic                   is_ext_result_under_min; // Indicates if the extended result is less than the min saturation value
  logic                   is_ext_result_over_max;  // Indicates if the extended result is greater than the max saturation value
  logic                   sel_min_sat_value;       // Selects the min saturation value as the result
  logic                   sel_max_sat_value;       // Selects the max saturation value as the result

  // Extend sources to WIDTH + 1 bits
  always_comb begin
    ext_srca = {(srca[WIDTH-1] & is_signed), srca};
    ext_srcb = {(srcb[WIDTH-1] & is_signed), srcb};
  end

  adder #(
    .WIDTH(WIDTH + 1)
  ) cla (
    .srca     (ext_srca          ),
    .srcb     (ext_srcb          ),
    .cin      (cin               ),
    .is_signed(is_signed         ),
    .result   (ext_result_pre_sat),
    .cout     (                  ),
    .zero_f   (                  ),
    .ov_f     (                  )
  );

  always_comb begin
    // Extend saturation values to compare with extended result
    ext_min_sat_value  = {(min_sat_value[WIDTH-1] & is_signed), min_sat_value};
    ext_max_sat_value  = {(max_sat_value[WIDTH-1] & is_signed), max_sat_value};

    // Overflow / underflow detection
    is_ext_result_under_min = is_signed
                            ? $signed(ext_result_pre_sat)   < $signed(ext_min_sat_value)
                            : $unsigned(ext_result_pre_sat) < $unsigned(ext_min_sat_value);
    is_ext_result_over_max  = is_signed
                            ? $signed(ext_result_pre_sat)   > $signed(ext_max_sat_value)
                            : $unsigned(ext_result_pre_sat) > $unsigned(ext_max_sat_value);

    // Qualify saturation with enablement signals
    sel_min_sat_value = sat_to_min & is_ext_result_under_min;
    sel_max_sat_value = sat_to_max & is_ext_result_over_max;

    // Select result source
    result_pre_sat = ext_result_pre_sat[WIDTH-1:0];

    result  = '0;
    result |= sel_min_sat_value
            ? min_sat_value
            : '0;
    result |= sel_max_sat_value
            ? max_sat_value
            : '0;
    result |= (~sel_min_sat_value & ~sel_max_sat_value)
            ? result_pre_sat
            : '0;
  end

endmodule
