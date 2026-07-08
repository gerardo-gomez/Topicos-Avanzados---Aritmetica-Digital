# Topicos Avanzados - Aritmetica Digital

La estructura de este repositorio consiste en:
- design/  : RTL de los entregables.
- docs/    : Documento técnico de cada tarea.
- fpga/    : Proyectos de Quartus para la implementación en FPGA.
- sim/     : Scripts utilizados para correr las pruebas en Questasim.
- verif/   : Testbenches de cada diseño.
- scripts/ : Scripts auxiliares miscelaneos.

A su vez, cada uno de estos directorios principales contiene subdirectorios correspondientes a cada tarea.
Por ejemplo, para la tarea "Adders": design/adders/, docs/adders, etc.

## Entregables

### Tareas
1. Adders
  - Documento técnico:                                  docs/adders/adders.pdf
  - Ripple Carry Adder top module:                      design/adders/rca.sv
  - Carry Look-Ahead top module:                        design/adders/cla.sv
  - Comando para correr simulación de TB Simple:        vsim -c -do ./sim/adders/*/run_msim.do
  - Comando para compilar y generar reportes de timing: source ./fpga/adders/*/fpga_flow.sh
2. Multipliers
  - Documento técnico:                                  docs/multipliers/multipliers.pdf
  - Array Multiplier top module:                        design/multipliers/array_wallace_mul.sv
  - Booth Wallace Multiplier top module:                design/multipliers/booth4_wallace_mul.sv
  - Comando para correr simulación de TB Simple:        vsim -c -do ./sim/multipliers/*/run_msim.do
  - Comando para compilar y generar reportes de timing: source ./fpga/multipliers/*/fpga_flow.sh
3. FMA
  - Documento técnico:                                  docs/fma/fma.pdf
  - FMA top module:                                     design/fma/fma.sv
  - FMA (independent multiply and addition) top module: design/fma/fma_split.sv
  - FMA behavioral top module:                          design/fma/fma_behav.sv
  - Comando para correr simulación de TB Simple:        vsim -c -do ./sim/fma/*/run_msim.do
  - Comando para compilar y generar reportes de timing: source ./fpga/fma/*/fpga_flow.sh
4. Dividers
5. Floating point
6. Saturación
  - Documento técnico:                                  docs/saturation/saturation.pdf
  - Adder Saturation top module:                        design/saturation/adder_sat.sv
  - Comando para correr simulación de TB Simple:        vsim -c -do ./sim/saturation/run_msim.do
  - Comando para compilar y generar reportes de timing: source ./fpga/saturation/fpga_flow.sh

### Proyecto