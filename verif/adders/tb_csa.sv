`timescale 1ns/1ns

module tb_csa;
  parameter int WIDTH  = 32;
  parameter int NUM_IN = 8;  // Number of input operands
  
  logic clk;
  
  logic [NUM_IN-1:0][WIDTH-1:0] operands;
  logic             [WIDTH-1:0] result;
  
  logic [WIDTH-1:0] exp_result;
  
  int num_pass;
  int num_errors;
  
  // Instantiate DUT
  csa_adder #(
    .WIDTH (WIDTH ),
    .NUM_IN(NUM_IN)
  ) dut (
    .operands(operands),
    .result  (result  )
  );
  
  initial begin
    clk = 0;
    forever begin
      #5 clk = ~clk;
    end
  end
  
  initial begin
    bit pass;
    num_pass   = 0;
	  num_errors = 0;
    
    for (int idx = 0; idx < 1000; idx++) begin
      @(posedge clk);
      exp_result = '0;
      for (int operand = 0; operand < NUM_IN; operand++) begin
      // Randomize data
        operands[operand] = $urandom();
      // Expected result
        exp_result += operands[operand];
      end
      // Check result
      @(negedge clk);
      pass = 1;
      pass &= (exp_result == result);
      
      if (pass) begin
        num_pass++;
      end else begin
        $error("Error, iteration: %0d, operands: %p, exp_result: 0x%0h, result: 0x%0h", idx, operands, exp_result, result);
        num_errors++;
      end
      
    end
    
    $display("NUM_PASS: %0d, NUM_ERRORS: %0d", num_pass, num_errors);
    
    if (num_errors == 0) begin
      $display ("TEST PASS");
    end else begin
      $display ("TEST FAILED");
    end

    $display("NUM_CSA_LEVELS: %0d", dut.wallace_tree.NUM_CSA_LEVELS);
    
    $stop();
//  $finish();
  end

endmodule