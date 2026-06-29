# Topicos Avanzados - Aritmetica Digital

La estructura de este repositorio consiste en:
- design/ : RTL de los entregables.
- docs/   : Documento técnico de cada tarea.
- fpga/   : Proyectos de Quartus para la implementación en FPGA.
- sim/    : Scripts utilizados para correr las pruebas en Questasim.
- verif/  : Testbenches de cada diseño.

A su vez, cada uno de estos directorios principales contiene subdirectorios correspondientes a cada tarea.
Por ejemplo, para la tarea "Adders": design/adders/, docs/adders, etc.

Entregables:
1. Adders
  - Documento técnico:                                 docs/adders/adders.pdf
  - Ripple Carry Adder top module:                     design/adders/rca.sv
  - Carry Look-Ahead top module:                       design/adders/cla.sv
  - Comando para correr simulación de TB Simple (CLI): vsim -c -do ./sim/adders/*/run_msim.do
2. Multipliers
3. FMA
4. Dividers
