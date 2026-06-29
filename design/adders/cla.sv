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

  localparam int ADDER_WIDTH = WIDTH;

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

  // Determina el residuo de n al dividirlo entre 4
  // Usado para determinar el numero de entradas del ultimo LCU o grupo de FA, si n no es multiplo de 4
  function automatic int f_get_remainder_4(input int n);
    return n % 4;
  endfunction

  // Determina cuantos grupos de 4 se forman en el numero n, si n no es multiplo de 4 se aumenta 1
  // Usado para determinal el numero de LCUs necesarios en cada nivel o grupos de 4 de FA
  function automatic int f_get_num_groups_4(input int n);
    return (n / 4) + (f_is_mult_4(n) ? 0 : 1);
  endfunction

  // Determina el numero de LCUs necesarios en cada nivel de jerarquia
  // El numero de LCUs en cada nivel depende del numero de LCUs del nivel anterior. Obtiene el numero de LCUs de cada nivel iterativamente hasta llegar al nivel deseado.
  // Para el nivel 0, el numero de LCUs depende del numero de FAs / ancho adder.
  function automatic int f_get_num_lcu_per_level(input int lvl);
    int curr_num_lcu;
    int prev_num_lcu = ADDER_WIDTH;
    for (int lvl_iter = 0; lvl_iter <= lvl; lvl_iter++) begin
      curr_num_lcu = f_get_num_groups_4(prev_num_lcu);
      prev_num_lcu = curr_num_lcu;
    end
    return curr_num_lcu;
  endfunction

  // Determina el numero de entradas del ultimo LCU en cada nivel de jerarquia
  // Checa si el numero de LCUs (o FAs para el nivel 0) en el nivel anterior es multiplo de 4, si no lo es regresa el residuo de la division entre 4
  function automatic int f_get_num_last_lcu_inputs(input int lvl);
    if (lvl == 0) begin
      return ( f_is_mult_4(ADDER_WIDTH)
             ? 4
             : f_get_remainder_4(ADDER_WIDTH));
    end
    return ( f_is_mult_4(f_get_num_lcu_per_level(lvl-1))
           ? 4
           : f_get_remainder_4(f_get_num_lcu_per_level(lvl-1)));
  endfunction

  localparam int LCU_WIDTH         = 4;
  localparam int NUM_LCU_LEVELS    = clog4_min1(ADDER_WIDTH);
  localparam int MAX_LCU_PER_LEVEL = f_get_num_groups_4(ADDER_WIDTH);

  // FA inputs
  logic [ADDER_WIDTH-1:0] fa_cin;
  // FA outputs
  logic [ADDER_WIDTH-1:0] fa_g;
  logic [ADDER_WIDTH-1:0] fa_p;

  // LCU inputs
  logic [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0]                lcu_cin;
  logic [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0][LCU_WIDTH-1:0] lcu_g;
  logic [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0][LCU_WIDTH-1:0] lcu_p;
  // LCU outputs
  logic [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0][LCU_WIDTH-1:0] lcu_c;
  logic [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0]                lcu_gg;
  logic [NUM_LCU_LEVELS-1:0][MAX_LCU_PER_LEVEL-1:0]                lcu_pg;

  // Genvars
  genvar fa;
  genvar lvl;
  genvar lcu;
  genvar lcu_lower;

  // Full-adders (FAs)
  generate
    for (fa = 0; fa < ADDER_WIDTH; fa++) begin : gen_fa
      fa_gp fa_gp (
        .a   (srca  [fa]),
        .b   (srcb  [fa]),
        .cin (fa_cin[fa]),
        .sum (result[fa]),
        .g   (fa_g  [fa]),
        .p   (fa_p  [fa])
      );
    end : gen_fa
  endgenerate

  // Look-Ahead Carry Units (LCUs)
  // Niveles de LCUs
  generate
    for (lvl = 0; lvl < NUM_LCU_LEVELS; lvl++) begin : gen_lvl
      localparam int NUM_LCUS            = f_get_num_lcu_per_level(lvl);
      localparam int LAST_LCU_ID         = NUM_LCUS - 1;
      localparam int NUM_LAST_LCU_INPUTS = f_get_num_last_lcu_inputs(lvl);

      for (lcu = 0; lcu < NUM_LCUS; lcu++) begin : gen_lcu

        // Instancias de LCUs por nivel
        lcu4 lcu4 (
          .g  (lcu_g  [lvl][lcu]),
          .p  (lcu_p  [lvl][lcu]),
          .cin(lcu_cin[lvl][lcu]),
          .c  (lcu_c  [lvl][lcu]),
          .gg (lcu_gg [lvl][lcu]),
          .pg (lcu_pg [lvl][lcu])
        );

        if (lvl == 0) begin : gen_lvl0_wires

          // Conectar FAs con el primer nivel de LCUs
          for (fa = 0; fa < LCU_WIDTH; fa++) begin : gen_fa_wires
            if ((lcu == LAST_LCU_ID) & (fa >= NUM_LAST_LCU_INPUTS)) begin
              assign lcu_g[lvl][lcu][fa] = 1'b0;                       // Atar las entradas de los LCUs que no se usan en el ultimo LCU del nivel si el numero de LCUs en
              assign lcu_p[lvl][lcu][fa] = 1'b1;                       // el nivel anterior no es multiplo de 4. Dichas entradas no generan carrys pero si los propagan.

            end else begin
              assign lcu_g[lvl][lcu][fa] = fa_g[lcu*LCU_WIDTH + fa];   // Generate de los FAs a las entradas de los LCUs
              assign lcu_p[lvl][lcu][fa] = fa_p[lcu*LCU_WIDTH + fa];   // Propagate de los FAs a las entradas de los LCUs

              assign fa_cin[lcu*LCU_WIDTH + fa] = lcu_c[lvl][lcu][fa]; // Carrys generados por los LCUs a las entradas de los FAs
            end // else
          end : gen_fa_wires

        end else begin : gen_lvlN_wires

          // Conectar los niveles de LCUs entre si
          for (lcu_lower = 0; lcu_lower < LCU_WIDTH; lcu_lower++) begin : gen_lcu_lower_wires
            if ((lcu == LAST_LCU_ID) & (lcu_lower >= NUM_LAST_LCU_INPUTS)) begin
              assign lcu_g[lvl][lcu][lcu_lower] = 1'b0;                                      // Atar las entradas de los LCUs que no se usan en el ultimo LCU del nivel si el numero de LCUs en
              assign lcu_p[lvl][lcu][lcu_lower] = 1'b1;                                      // el nivel anterior no es multiplo de 4. Dichas entradas no generan carrys pero si los propagan.

            end else begin
              assign lcu_g[lvl][lcu][lcu_lower] = lcu_gg[lvl-1][lcu*LCU_WIDTH + lcu_lower];  // Group Generate  (GG) de los LCUs del nivel anterior a las entradas de los LCUs del nivel actual
              assign lcu_p[lvl][lcu][lcu_lower] = lcu_pg[lvl-1][lcu*LCU_WIDTH + lcu_lower];  // Group Propagate (PG) de los LCUs del nivel anterior a las entradas de los LCUs del nivel actual

              assign lcu_cin[lvl-1][lcu*LCU_WIDTH + lcu_lower] = lcu_c[lvl][lcu][lcu_lower]; // Carrys generados por los LCUs del nivel actual a las entradas de los LCUs del nivel anterior
            end // else
          end : gen_lcu_lower_wires

        end : gen_lvlN_wires
      end : gen_lcu
    end : gen_lvl
  endgenerate

  // Conectar el ultimo nivel de LCUs con los carrys de entrada y salida del adder
  assign lcu_cin[NUM_LCU_LEVELS-1][0] = cin;                                       // Carry de entrada del adder a la entrada del LCU del nivel mas alto

  assign cout = lcu_gg[NUM_LCU_LEVELS-1][0] | (lcu_pg[NUM_LCU_LEVELS-1][0] & cin); // Carry de salida del adder

  // Flags
  assign zero_f = ~(|result);
  assign ov_f   = is_signed
                ? ((srca[ADDER_WIDTH-1] ^ result[ADDER_WIDTH-1]) & (srcb[ADDER_WIDTH-1] ^ result[ADDER_WIDTH-1])) // Overflow para signed:   si el signo del resultado es diferente al de ambos operandos
                : cout;                                                                                           // Overflow para unsigned: si hay carry de salida

endmodule
