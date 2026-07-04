// Description: Wrapper to test the Wallace tree adder with 3:2 compressors (carry save adders)

module csa_adder #(
  parameter  int WIDTH   = 16, // Width of the operands
  parameter  int NUM_IN  = 8   // Number of input operands
)(
  input  logic [NUM_IN-1:0][WIDTH-1:0] tree_in,
  output logic             [WIDTH-1:0] result,
  output logic                         cout
); 

  localparam int NUM_OUT = 2; // Number of output operands from wallace tree

  logic [NUM_OUT-1:0][WIDTH-1:0] tree_out;

  wallace_tree #(
      .WIDTH (WIDTH ),
      .NUM_IN(NUM_IN)
  ) wallace_tree (
      .in (tree_in ),
      .out(tree_out)
  );

  assign {cout, result} = {1'b0, tree_out[1]} + {1'b0, tree_out[0]};

endmodule
