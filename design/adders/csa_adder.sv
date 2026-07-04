// Description: Wrapper to test the Wallace tree adder with 3:2 compressors (carry save adders)

module csa_adder #(
  parameter  int WIDTH   = 16, // Width of the operands
  parameter  int NUM_IN  = 8   // Number of input operands
)(
  input  logic [NUM_IN-1:0][WIDTH-1:0] operands,
  output logic             [WIDTH-1:0] result
); 

  localparam int NUM_OUT = 2; // Number of output operands from wallace tree

  logic [NUM_IN-1:0] [WIDTH-1:0] operands_in;
  logic [NUM_OUT-1:0][WIDTH-1:0] operands_out;

  assign operands_in = operands;

  wallace_tree #(
      .WIDTH (WIDTH ),
      .NUM_IN(NUM_IN)
  ) wallace_tree (
      .operands_in (operands_in ),
      .operands_out(operands_out)
  );

  assign result = operands_out[1] + operands_out[0];

endmodule
