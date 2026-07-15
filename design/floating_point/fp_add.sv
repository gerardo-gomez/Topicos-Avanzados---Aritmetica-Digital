// Description: Half precision (16-bits) floating point adder

module fp_add(
  input  logic [15:0] srca,
  input  logic [15:0] srcb,
  input  logic [2:0]  rm,      // modo de redondeo   RNE=0, RTZ=1, RDN=2, RUP=3, RMM=4
  output logic [15:0] result,
  output logic [4:0]  fflags   // {NV, DZ, OF, UF, NX}
);

endmodule
