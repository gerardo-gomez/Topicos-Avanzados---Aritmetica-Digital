// Description: N-bits Carry Look-Ahead Adder with 4-bit Look-Ahead Carry Unit (LCU)
// Contact:     Gerardo Gomez

module adder #(
  parameter int WIDTH = 16             // Ancho del adder
)(
  input  logic [WIDTH-1:0] srca,       // Operando 1
  input  logic [WIDTH-1:0] srcb,       // Operando 2
  input  logic             cin,        // Carry de entrada
  input  logic             is_signed,  // Indica si la operacion es signed(1) o unsigned(0)
  output logic [WIDTH-1:0] result,     // Resultado
  output logic             cout,       // Carry de salida
  output logic             zero_f,     // Bandera de cero
  output logic             ov_f        // Bandera de overflow
); 

  // Logaritmo base 4 redondeado hacia arriba y que regresa 1 como valor minimo
  // Esta funcion es necesaria para determinar el numero de niveles de LCU necesarios para un adder de ancho WIDTH, ya que cada LCU maneja 4 bits
  function automatic int clog4_min1(input int n);
    if (n <= 4) return 1;
    return ($clog2(n) + 1) / 2;
  endfunction

  // Determina si un numero es multiplo de 4
  // Usado para determinar si se necesitara un LCU o grupo (incompleto) de FA adicional 
  function automatic int f_is_mult_4(input int n);
    return (n % 4) == 0;
  endfunction

  // Determina cuantos grupos de 4 se forman en el numero n, si n no es multiplo de 4 se aumenta 1
  // Usado para determinal el numero de LCUs necesarios en cada nivel o grupos de 4 de FA
  function automatic int f_get_num_groups_4(input int n);
    return (n / 4) + (f_is_mult_4(n) ? 0 : 1);
  endfunction

  // Determina el numero de LCUs necesarios en cada nivel de jerarquia
  // Basada en la funcion f_get_num_groups_4, pero llamada recursivamente ya que el numero en cada nivel depende del numero de LCUs del nivel anterior
  function automatic int f_get_num_lcu_per_level(input int lvl);
    if (lvl == 0) return f_get_num_groups_4(ADDER_WIDTH);
    return f_get_num_groups_4(f_get_num_lcu_per_level(lvl-1));
  endfunction

  localparam int ADDER_WIDTH       = WIDTH;
  localparam int LCU_WIDTH         = 4;
  localparam int NUM_LCU_LEVELS    = clog4_min1(ADDER_WIDTH);
  localparam int MAX_LCU_PER_LEVEL = f_get_num_groups_4(ADDER_WIDTH);
  localparam int NUM_FA_GROUPS     = MAX_LCU_PER_LEVEL;

  typedef logic [LCU_WIDTH-1:0] t_lcu_g;
  typedef logic [LCU_WIDTH-1:0] t_lcu_p;
  typedef logic [LCU_WIDTH-1:0] t_lcu_c;

  t_lcu_g [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0] lcu_g;
  t_lcu_p [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0] lcu_p;
  logic   [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0] lcu_cin;
  t_lcu_c [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0] lcu_c;
  logic   [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0] lcu_gg;
  logic   [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0] lcu_pg;

  logic [ADDER_WIDTH-1:0] fa_cin;
  logic [ADDER_WIDTH-1:0] fa_g;
  logic [ADDER_WIDTH-1:0] fa_p;

  // Full-adders
  for (genvar fa = 0; fa < ADDER_WIDTH; fa++) begin : gen_fa
    fa_gp fa (
      .a   (srca  [fa]),
      .b   (srcb  [fa]),
      .cin (fa_cin[fa]),
      .sum (result[fa]),
      .g   (fa_g  [fa]),
      .p   (fa_p  [fa])
    );
  end : gen_fa

  // Look-Ahead Carry Units
  for (genvar lvl = 0; lvl < NUM_LCU_LEVELS; lvl++) begin : gen_lvl
    localparam int NUM_LCUS = f_get_num_lcu_per_level(lvl);

    for (genvar lcu = 0; lcu < NUM_LCUS; lcu++) begin : gen_lcu
      lcu4 lcu (
        .g  (lcu_g  [lvl][lcu]),
        .p  (lcu_p  [lvl][lcu]),
        .cin(lcu_cin[lvl][lcu]),
        .c  (lcu_c  [lvl][lcu]),
        .gg (lcu_gg [lvl][lcu]),
        .pg (lcu_pg [lvl][lcu])
      );
    end : gen_lcu
  end : gen_lvl

  // Flags
  assign zero_f = ~(|result);
  assign ov_f   = is_signed
                ? ((srca[ADDER_WIDTH-1] ^ result[ADDER_WIDTH-1]) & (srcb[ADDER_WIDTH-1] ^ result[ADDER_WIDTH-1])) // Overflow para signed:   si el signo del resultado es diferente al de ambos operandos
                : cout;                                                                                           // Overflow para unsigned: si hay carry de salida

endmodule
