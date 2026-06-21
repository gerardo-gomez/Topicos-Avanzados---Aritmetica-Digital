// Description: 4-bit Look-Ahead Carry Unit

module lcu4 (
  input  logic [3:0] g,
  input  logic [3:0] p,
  input  logic       cin,
  output logic [3:0] c,
//output logic       cout,
  output logic       gg,  // Group Generate  (GG): Se genera un carry a través de todo el bloque
  output logic       pg   // Group Propagate (PG): Se propag el carry de entrada a través de todo el bloque
);

  // Generacion de los carrys:
  //         Lo genera...            o lo propaga y el anterior lo genera...              o lo propaga todo y hay carry de entrada
  //            v                       v             v                                      v                             v
  assign c[0] =                                                                                                            cin;
  assign c[1] = g[0]                                                                      | (                     p[0] & c[0]);
  assign c[2] = g[1]                                        | (              p[1] & g[0]) | (              p[1] & p[0] & c[0]);
  assign c[3] = g[2]                 | (       p[2] & g[1]) | (       p[2] & p[1] & g[0]) | (       p[2] & p[1] & p[0] & c[0]);
//assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & c[0]); // cout = c[4] = gg | (pg & cin)
  assign gg   = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);
  assign pg   =                                                                              p[3] & p[2] & p[1] & p[0];
//assign cout = gg                                                                        | (pg                        & cin);

endmodule
