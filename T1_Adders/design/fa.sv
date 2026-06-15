// Description: Full Adder

// Implementación con expresión de mayoría para Cout
module fa (
  input  logic a, b, cin,
  output logic sum, cout
);
  assign sum  = a ^ b ^ cin;
  assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

// Equivalente (también común)
module fa_alt (
  input  logic a, b, cin,
  output logic sum, cout
);
  assign sum  = a ^ b ^ cin;
  assign cout = (a & b) | ((a ^ b) & cin);   // path por XOR para Cout
endmodule
