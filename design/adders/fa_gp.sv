// Description: Full-Adder modificado para uso en Carry Look-Ahead Adder (generate-propagate)

module fa_gp (
  input  logic a, b, cin,
  output logic sum, /*cout*/
  output logic g, p
);
  assign g = a & b;            // generate
  assign p = a ^ b;            // propagate
//assign sum  = a ^ b ^ cin;
  assign sum  =   p   ^ cin;
//assign cout = (a & b) | ((a ^ b) & cin);
//assign cout = (  g  ) | ((  p  ) & cin);
endmodule

// Notese similitud con el modulo de full-adder alternativo (Cout reescrito)
//module fa_alt (
//  input  logic a, b, cin,
//  output logic sum, cout
//);
//  assign sum  = a ^ b ^ cin;
//  assign cout = (a & b) | ((a ^ b) & cin);   // path por XOR para Cout
//endmodule
