// Description: ROM with asynchrounous read logic with the weights for layer 1 and layer 2.
// Notes about synthesis in Quartus:
// - M10K RAM blocks cannot be inferred in the Cyclone V due to asynchronous
//   read logic. Using FPGA core logic instead.

module weights_rom
    import neural_network_pkg::*;
(
    input  logic               [WEIGHTS_ROM_ADDR_WIDTH-1:0] addr,   // Address
    output logic [NUM_MULS-1:0][WEIGHT_WIDTH          -1:0] weights // Read Data
);

  logic [WEIGHTS_ROM_DATA_WIDTH-1:0] read_data;

  (* romstyle = "logic" *) logic [WEIGHTS_ROM_DATA_WIDTH-1:0] rom_data [WEIGHTS_ROM_DEPTH-1:0];

  initial $readmemh (WEIGHTS_ROM_FILE, rom_data);

  assign read_data = rom_data[addr]; // Asynchronous read logic

  assign weights = {read_data[63:56], read_data[55:48], read_data[47:40], read_data[39:32],
                    read_data[31:24], read_data[23:16], read_data[15:8],  read_data[7:0]};

endmodule
