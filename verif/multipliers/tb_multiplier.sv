`timescale 1ns/1ns

module tb_multiplier;
  parameter int SRC1_WIDTH   = 32;
  parameter int SRC2_WIDTH   = SRC1_WIDTH;
  parameter int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH);
  
  logic clk;
  
  logic [SRC1_WIDTH-1:0]   srca;
  logic [SRC2_WIDTH-1:0]   srcb;
  logic [RESULT_WIDTH-1:0] result;
  logic is_signed;
  
  logic [RESULT_WIDTH-1:0] exp_result;
  
  int num_pass;
  int num_errors;
  
  // Instantiate DUT
  multiplier #(
    .SRC1_WIDTH(SRC1_WIDTH),
    .SRC2_WIDTH(SRC2_WIDTH)
  )dut(
    .srca(srca),
    .srcb(srcb),
    .is_signed(is_signed),
    .result(result)
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
      // Randomize data
      srca      = $urandom();
      srcb      = $urandom();
      is_signed = $urandom();
      // Expected result
      if (is_signed) begin
        exp_result = $signed(srca) * $signed(srcb);
      end else begin
        exp_result = $unsigned(srca) * $unsigned(srcb);
      end
      // Check result
      @(negedge clk);
      pass = 1;
      pass &= (exp_result == result);
      
      if (pass) begin
        num_pass++;
      end else begin
        $error("Error, iteration: %0d, srca: 0x%0h, srcb: 0x%0h, is_signed: %0b, exp_result: 0x%0h, result: 0x%0h", idx, srca, srcb, is_signed, exp_result, result);
        num_errors++;
      end
      
    end
    
    $display("NUM_PASS: %0d, NUM_ERRORS: %0d", num_pass, num_errors);
    
    if (num_errors == 0) begin
      $display ("TEST PASS");
    end else begin
      $display ("TEST FAILED");
    end
    
    $finish();
    
  end
  
  
  
endmodule