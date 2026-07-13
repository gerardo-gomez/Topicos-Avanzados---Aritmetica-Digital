// Description: ROM with asynchrounous read logic with the biases for layer 1 and layer 2.
//              Memory layout: 16 layer-1 biases then 10 layer-2 biases, int32 = total 26 32-bit entries
// Notes about synthesis in Quartus:
// - M10K RAM blocks cannot be inferred in the Cyclone V due to asynchronous
//   read logic. Using FPGA core logic instead.

module biases_rom #(
    // Fixed parameters (DO NOT MODIFY)
    parameter int BIAS_WIDTH     = 32,
    parameter int ROM_DEPTH      = 26,
    parameter int ROM_ADDR_WIDTH = $clog2(ROM_DEPTH),
    parameter int ROM_DATA_WIDTH = BIAS_WIDTH,
    parameter int ROM_FILE       = "biases.hex"
)(
    input  logic [ROM_ADDR_WIDTH-1:0] addr, // Address
    output logic [BIAS_WIDTH    -1:0] bias  // Read Data
);

  logic [ROM_DATA_WIDTH-1:0] read_data;

  (* romstyle = "logic" *) logic [ROM_DATA_WIDTH-1:0] rom_data [ROM_DEPTH-1:0];

  initial $readmemh (ROM_FILE, rom_data);

  assign read_data = rom_data[addr]; // Asynchronous read logic

  assign bias = read_data;

endmodule
