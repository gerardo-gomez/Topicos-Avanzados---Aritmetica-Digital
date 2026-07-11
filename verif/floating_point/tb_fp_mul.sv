
`timescale 1ns/1ns

//============================================================================
// tb_fp_mul
//
// Testbench para un multiplicador FP16 (IEEE-754 half precision).
//
// El resultado golden se precalcula con Berkeley SoftFloat (ver
// gen_f16_mul_vectors.c) y se vuelca a un archivo de texto. Este TB lee ese
// archivo, aplica los operandos al DUT y compara resultado + banderas IEEE.
//
// Formato de cada linea del archivo de vectores (todos en hexadecimal):
//     <rm> <a> <b> <result> <flags>
//   rm     : modo de redondeo (frm RISC-V): 0=RNE 1=RTZ 2=RDN 3=RUP 4=RMM
//   a,b    : operandos f16 (16 bits)
//   result : resultado golden f16 (16 bits)
//   flags  : fflags RISC-V: bit4=NV bit3=DZ bit2=OF bit1=UF bit0=NX
//============================================================================

module tb_fp_mul;
  parameter string VECTOR_FILE = "f16_mul_vectors.txt";

  logic clk;

  // --- Estimulos hacia el DUT ---
  logic [15:0] srca;
  logic [15:0] srcb;
  logic [2:0]       rm;        // modo de redondeo

  // --- Salidas del DUT ---
  logic [15:0] result;
  logic [4:0]       fflags;    // {NV, DZ, OF, UF, NX}

  // --- Valores esperados (golden, leidos del archivo) ---
  logic [15:0] exp_result;
  logic [4:0]       exp_flags;

  int num_pass;
  int num_errors;

  //--------------------------------------------------------------------------
  // Instancia del DUT.
  // NOTA: ajusta el nombre del modulo y de los puertos a tu RTL real.
  //--------------------------------------------------------------------------
  fp_mul dut (
    .srca   (srca),
    .srcb   (srcb),
    .rm     (rm),
    .result (result),
    .fflags (fflags)
  );

  // Reloj
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  //--------------------------------------------------------------------------
  // Proceso principal: lee vectores, aplica y compara.
  //--------------------------------------------------------------------------
  initial begin
    int    fd;
    int    code;
    int    idx;
    bit    pass;

    // Campos leidos del archivo (int para $fscanf con %h)
    int rm_i, a_i, b_i, res_i, flags_i;

    num_pass   = 0;
    num_errors = 0;
    idx        = 0;

    fd = $fopen(VECTOR_FILE, "r");
    if (fd == 0) begin
      $fatal(1, "No se pudo abrir el archivo de vectores: %s", VECTOR_FILE);
    end

    while (!$feof(fd)) begin
      code = $fscanf(fd, "%h %h %h %h %h",
                     rm_i, a_i, b_i, res_i, flags_i);
      if (code != 5) begin
        // Linea vacia o incompleta (p. ej. EOL final): ignorar.
        continue;
      end

      // Aplicar estimulos en el flanco de subida
      @(posedge clk);
      srca       = a_i[15:0];
      srcb       = b_i[15:0];
      rm         = rm_i[2:0];
      exp_result = res_i[15:0];
      exp_flags  = flags_i[4:0];

      // Comparar en el flanco de bajada (da tiempo a la logica combinacional)
      @(negedge clk);
      pass  = 1;
      pass &= (exp_result == result);
      pass &= (exp_flags  == fflags);

      if (pass) begin
        num_pass++;
      end else begin
        $error({"Error iter %0d: rm=%0d srca=0x%04h srcb=0x%04h | ",
                "exp_result=0x%04h result=0x%04h | exp_flags=0x%02h fflags=0x%02h"},
               idx, rm, srca, srcb,
               exp_result, result, exp_flags, fflags);
        num_errors++;
      end

      idx++;
    end

    $fclose(fd);

    $display("NUM_PASS: %0d, NUM_ERRORS: %0d", num_pass, num_errors);
    if (num_errors == 0)
      $display("TEST PASS");
    else
      $display("TEST FAILED");

    $finish();
  end

endmodule
