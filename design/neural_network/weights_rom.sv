// Description: ROM with asynchrounous read logic with the weights for layer 1 and layer 2.
//              Original memory layout: layer1: 16 neurons x 64 int8 weights, then layer2: 10 x 16 = total 1184 8-bit entries
//              Adjusted memory layout to read 8 weight values per read (1184 / 8):                = total 148 64-bit entries
// Notes about synthesis in Quartus:
// - M10K RAM blocks cannot be inferred in the Cyclone V due to asynchronous
//   read logic. Using FPGA core logic instead.

module weights_rom
#(
    // Fixed parameters (DO NOT MODIFY)
    parameter int NUM_WEIGHTS_READ = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int ROM_DEPTH        = 148,
    parameter int ROM_ADDR_WIDTH   = $clog2(ROM_DEPTH),
    parameter int ROM_DATA_WIDTH   = 64,
    parameter int ROM_FILE         = "weights.hex"
)(
    input  logic                       [ROM_ADDR_WIDTH-1:0] addr,   // Address
    output logic [NUM_WEIGHTS_READ-1:0][WEIGHT_WIDTH  -1:0] weights // Read Data
);

  logic [ROM_DATA_WIDTH-1:0] read_data;

  (* romstyle = "logic" *) logic [ROM_DATA_WIDTH-1:0] rom_data [ROM_DEPTH-1:0];

  initial $readmemh (ROM_FILE, rom_data);

  assign read_data = rom_data[addr]; // Asynchronous read logic

  assign weights = {read_data[63:56], read_data[55:48], read_data[47:40], read_data[39:32],
                    read_data[31:24], read_data[23:16], read_data[15:8],  read_data[7:0]};

endmodule
