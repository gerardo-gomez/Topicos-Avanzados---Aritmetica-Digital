// Descripcion: Top level del fp_adder para implementacion en FPGA y analisis de timing

module fpga_top #(
  parameter int WIDTH = 16             // Ancho del fp_adder (half precision)
)(
  input  logic clk,

  input  logic [WIDTH-1:0] srca_in,    // Operando 1 (f16)
  input  logic [WIDTH-1:0] srcb_in,    // Operando 2 (f16)
  input  logic             op_in,      // 0 = add, 1 = sub
  input  logic [2:0]       rm_in,      // Modo de redondeo (RNE=0, RTZ=1, RDN=2, RUP=3, RMM=4)
  output logic [WIDTH-1:0] result_out, // Resultado (f16)
  output logic [4:0]       fflags_out  // Banderas IEEE {NV, DZ, OF, UF, NX}
);

  // Flopped FPGA inputs signals
  // FF.D
  logic [WIDTH-1:0] srca_d;
  logic [WIDTH-1:0] srcb_d;
  logic             op_d;
  logic [2:0]       rm_d;
  // FF.Q
  logic [WIDTH-1:0] srca_q;
  logic [WIDTH-1:0] srcb_q;
  logic             op_q;
  logic [2:0]       rm_q;

  // Flopped FPGA outputs signals
  // FF.D
  logic [WIDTH-1:0] result_d;
  logic [4:0]       fflags_d;
  // FF.Q
  logic [WIDTH-1:0] result_q;
  logic [4:0]       fflags_q;

  // fp_adder instance signals
  logic [WIDTH-1:0] srca;
  logic [WIDTH-1:0] srcb;
  logic             op;
  logic [2:0]       rm;
  logic [WIDTH-1:0] result;
  logic [4:0]       fflags;

  //////////////////////////////////////////////////////////////////////////////////////
  // Instantiate fp_adder
  //////////////////////////////////////////////////////////////////////////////////////

  fp_adder fp_adder (
    .srca  (srca  ), // Operando 1 (f16)
    .srcb  (srcb  ), // Operando 2 (f16)
    .op    (op    ), // 0 = add, 1 = sub
    .rm    (rm    ), // Modo de redondeo
    .result(result), // Resultado (f16)
    .fflags(fflags)  // Banderas IEEE {NV, DZ, OF, UF, NX}
  );

  //////////////////////////////////////////////////////////////////////////////////////
  // Connect flopped fp_adder instance signals
  //////////////////////////////////////////////////////////////////////////////////////

  // Flopped FPGA inputs to fp_adder instance inputs
  assign srca = srca_q;
  assign srcb = srcb_q;
  assign op   = op_q;
  assign rm   = rm_q;

  // Flopped fp_adder instance outputs to FPGA outputs
  assign result_out = result_q;
  assign fflags_out = fflags_q;

  //////////////////////////////////////////////////////////////////////////////////////
  // Flop FPGA ports
  //////////////////////////////////////////////////////////////////////////////////////

  // Connect FPGA inputs to FF.D
  assign srca_d = srca_in;
  assign srcb_d = srcb_in;
  assign op_d   = op_in;
  assign rm_d   = rm_in;

  // Connect fp_adder instance outputs to FF.D
  assign result_d = result;
  assign fflags_d = fflags;

  // Flop FPGA inputs
  always_ff @(posedge clk) begin
    srca_q <= srca_d;
    srcb_q <= srcb_d;
    op_q   <= op_d;
    rm_q   <= rm_d;
  end

  // Flop fp_adder instance outputs
  always_ff @(posedge clk) begin
    result_q <= result_d;
    fflags_q <= fflags_d;
  end

endmodule
