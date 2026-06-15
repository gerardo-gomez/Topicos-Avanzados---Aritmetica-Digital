// Description: 4-bit Look-Ahead Carry Unit

module lcu4 (
  input  logic [3:0] g,
  input  logic [3:0] p,
  input  logic       cin,
  output logic [4:1] cout,
  output logic       gg, pg
);

  logic [4:0] c;

  assign c[0] = cin;
  assign c[1] = g[0] | (p[0] & c[0]);
  assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
  assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c[0]);
  assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & c[0]);

  assign cout[4:1] = c[4:1];

  // Group propagate (PG) and group generate (GG)
  assign pg = p[0] & p[1] & p[2] & p[3];                                                 // PG: se propagan los carry a través de todo el bloque
  assign gg = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]); // GG: se genera un carry a través de todo el bloque

endmodule
