// Description: Carry Save Adder (CSA) / 3:2 Compressor

module csa #(
    parameter  int WIDTH   = 32, // Width of the operands
    localparam int NUM_IN  = 3,  // Number of input operands
    localparam int NUM_OUT = 2   // Number of output operands
) (
    input  logic [NUM_IN -1:0][WIDTH-1:0] in,
    output logic [NUM_OUT-1:0][WIDTH-1:0] out
);

  // 3 input operands: A, B, C
  logic [ WIDTH     -1:0] a, b, c;
  // 2 output operands: S, CY
  logic [ WIDTH     -1:0] s;
  logic [(WIDTH + 1)-1:0] cy;

  // Input assignments
  assign a = in[0];
  assign b = in[1];
  assign c = in[2];
  // Output assignments
  assign out[0] = s;
  assign out[1] = cy[WIDTH-1:0]; // Shifted-out carry is lost (cy[WIDTH] not used)

  generate
    // Full-adders instances side-by-side (no carry chain)
    for (genvar fa_i = 0; fa_i < WIDTH; fa_i++) begin : gen_fa
      fa fa (
        .a   (a [fa_i  ]),
        .b   (b [fa_i  ]),
        .cin (c [fa_i  ]),
        .sum (s [fa_i  ]),
        .cout(cy[fa_i+1])  // cy = shifted carries by 1 bit to the left
      );                   

      if (fa_i == 0) begin
        assign cy[fa_i] = 1'b0; // Shifted-in carry is 0 (cy[0] = 0)
      end
    end : gen_fa
  endgenerate

endmodule
