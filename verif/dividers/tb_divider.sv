// Code your testbench here
// or browse Examples
`timescale 1ns/1ns

module tb_divider;
  parameter int WIDTH = 64;
  
  logic clk;
  
  logic [WIDTH-1:0] srca;
  logic [WIDTH-1:0] srcb;
  logic [WIDTH-1:0] result;
  logic [WIDTH-1:0] rem;
  logic is_signed;
  logic div_zero_f;
  
  logic [WIDTH-1:0] exp_result;
  logic [WIDTH-1:0] exp_rem;
  logic exp_div_zer_f;
  
  int num_pass;
  int num_errors;
  
  // Instantiate DUT
  divider #(
    .WIDTH(WIDTH) 
  )dut(
    .srca(srca),
    .srcb(srcb),
    .is_signed(is_signed),
    .result(result),
    .rem(rem),
    .div_zero_f(div_zero_f)
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
      exp_div_zer_f = 0;
      if (srcb == 0) begin
        exp_result    = '1;
        exp_rem       = srca;
        exp_div_zer_f = 1;
      end else if (is_signed) begin
        exp_result = $signed(srca) / $signed(srcb);
        exp_rem    = $signed(srca) % $signed(srcb);
      end else begin
        exp_result = $unsigned(srca) / $unsigned(srcb);
        exp_rem    = $unsigned(srca) % $unsigned(srcb);
      end
      // Check result
      @(negedge clk);
      pass = 1;
      pass &= (exp_result    == result);
      pass &= (exp_rem       == rem);
      pass &= (exp_div_zer_f == exp_div_zer_f);
      
      if (pass) begin
        num_pass++;
      end else begin
        $error("Error, iteration: %0d, srca: 0x%0h, srcb: 0x%0h, is_signed: %0b, exp_result: 0x%0h, result: 0x%0h, exp_rem: %0b, rem: %0b, exp_div_zer_f: %0b, div_zero_f: %0b", idx, srca, srcb, is_signed, exp_result, result, exp_rem, rem, exp_div_zer_f, div_zero_f);
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