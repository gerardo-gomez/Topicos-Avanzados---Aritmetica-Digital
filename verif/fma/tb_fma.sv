`timescale 1ns/1ns

module tb_fma;
  parameter int SRC1_WIDTH   = 64;
  parameter int SRC2_WIDTH   = SRC1_WIDTH;
  parameter int SRC3_WIDTH   = SRC1_WIDTH;
  parameter int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH);
  
  logic clk;
  
  logic [SRC1_WIDTH-1:0]   srca;
  logic [SRC2_WIDTH-1:0]   srcb;
  logic [SRC3_WIDTH-1:0]   srcc;
  logic [RESULT_WIDTH-1:0] result;
  logic is_signed;
  logic is_fma;
  
  logic [RESULT_WIDTH-1:0] exp_result;
  
  int num_pass;
  int num_errors;
  
  // Instantiate DUT
  fma #(
    .SRC1_WIDTH(SRC1_WIDTH),
    .SRC2_WIDTH(SRC2_WIDTH),
    .SRC3_WIDTH(SRC3_WIDTH)
  )dut(
    .srca(srca),
    .srcb(srcb),
    .srcc(srcc),
    .is_fma(is_fma),
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
      srcc      = $urandom();
      is_signed = $urandom();
      is_fma    = $urandom();
      // Expected result
      if (is_signed) begin
        exp_result = $signed(srca) * $signed(srcb);
        if (is_fma) begin
          exp_result = $signed(exp_result) + $signed(srcc);
        end
      end else begin
        exp_result = $unsigned(srca) * $unsigned(srcb);
        if (is_fma) begin
          exp_result += $unsigned(srcc);
        end
      end
      // Check result
      @(negedge clk);
      pass = 1;
      pass &= (exp_result == result);
      
      if (pass) begin
        num_pass++;
      end else begin
        $error("Error, iteration: %0d, srca: 0x%0h, srcb: 0x%0h, srcc: 0x%0h, is_signed: %0b, is_fma: %0b, exp_result: 0x%0h, result: 0x%0h", idx, srca, srcb, srcc, is_signed, is_fma, exp_result, result);
        num_errors++;
      end
      
    end
    
    $display("NUM_PASS: %0d, NUM_ERRORS: %0d", num_pass, num_errors);
    
    if (num_errors == 0) begin
      $display ("TEST PASS");
    end else begin
      $display ("TEST FAILED");
    end
    
//  $finish();
    $stop();
    
  end
  
  
  
endmodule