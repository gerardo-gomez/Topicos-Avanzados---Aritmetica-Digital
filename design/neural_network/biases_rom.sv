// Description: ROM with asynchrounous read logic with the biases for layer 1 and layer 2.
// Notes about synthesis in Quartus:
// - M10K RAM blocks cannot be inferred in the Cyclone V due to asynchronous
//   read logic. Using FPGA core logic instead.

module biases_rom
    import neural_network_pkg::*;
(
    input  logic [BIASES_ROM_ADDR_WIDTH-1:0] addr, // Address
    output logic [BIAS_WIDTH           -1:0] bias  // Read Data
);

  logic [BIASES_ROM_DATA_WIDTH-1:0] read_data;

  (* romstyle = "logic" *) logic [BIASES_ROM_DATA_WIDTH-1:0] rom_data [BIASES_ROM_DEPTH-1:0];

  initial $readmemh (BIASES_ROM_FILE, rom_data);

  assign read_data = rom_data[addr]; // Asynchronous read logic

  assign bias = read_data;

endmodule
