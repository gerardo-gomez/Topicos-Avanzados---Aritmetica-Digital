// Description: 4-bit Carry Look-Ahead Adder

module cla4 (
  input  logic [3:0] a,
  input  logic [3:0] b,
  input  logic       cin,
  output logic [3:0] sum,
  output logic       cout
);

  logic [3:0] g, p;
  logic [4:0] c;

  assign g = a & b;            // generate
  assign p = a ^ b;            // propagate

  assign c[0] = cin;
  assign c[1] = g[0] | (p[0] & c[0]);
  assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
  assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0])
                     | (p[2] & p[1] & p[0] & c[0]);
  assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1])
                     | (p[3] & p[2] & p[1] & g[0])
                     | (p[3] & p[2] & p[1] & p[0] & c[0]);

  assign sum  = p ^ c[3:0];
  assign cout = c[4];

endmodule
