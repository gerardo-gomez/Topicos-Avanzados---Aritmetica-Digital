// Code your testbench here
// or browse Examples
`timescale 1ns/1ns

module tb_divider;
  parameter  int WIDTH = 64;

  localparam int NUM_TESTS        = 1000;
  localparam int PIPELINE_LATENCY = WIDTH + 2;
  
  logic clk;
  
  logic [WIDTH-1:0] srca      [(WIDTH+1):0];
  logic [WIDTH-1:0] srcb      [(WIDTH+1):0];
  logic             is_signed [(WIDTH+1):0];
  logic [WIDTH-1:0] result;
  logic [WIDTH-1:0] rem;
  logic             div_zero_f;
  
  logic [WIDTH-1:0] exp_result     [(WIDTH+1):0];
  logic [WIDTH-1:0] exp_rem        [(WIDTH+1):0];
  logic             exp_div_zero_f [(WIDTH+1):0];
  
  int num_pass;
  int num_errors;
  
  // Instantiate DUT
  divider #(
    .WIDTH(WIDTH) 
  )dut(
    .clk       (clk         ),
    .srca      (srca     [0]),
    .srcb      (srcb     [0]),
    .is_signed (is_signed[0]),
    .result    (result      ),
    .rem       (rem         ),
    .div_zero_f(div_zero_f  )
  );
  
  initial begin
    clk = 0;
    forever begin
      #5 clk = ~clk;
    end
  end

  // Generate test vectors
  initial begin
    for (int idx = 0; idx < NUM_TESTS; idx++) begin
      @(posedge clk);
      // Randomize data
      srca     [0] = $urandom();
      srcb     [0] = $urandom();
      is_signed[0] = $urandom();
      // Expected result
      exp_div_zero_f[0] = 0;
      if (srcb[0] == 0) begin
        exp_result    [0] = '1;
        exp_rem       [0] = srca[0];
        exp_div_zero_f[0] = 1;
      end else if (is_signed[0]) begin
        exp_result[0] = $signed(srca[0]) / $signed(srcb[0]);
        exp_rem   [0] = $signed(srca[0]) % $signed(srcb[0]);
      end else begin
        exp_result[0] = $unsigned(srca[0]) / $unsigned(srcb[0]);
        exp_rem   [0] = $unsigned(srca[0]) % $unsigned(srcb[0]);
      end
    end // for
  end // initial (Generate test vectors)

  // Check results
  initial begin
    bit pass;
    num_pass   = 0;
	  num_errors = 0;
    
    // Wait for pipeline to fill
    repeat (PIPELINE_LATENCY) begin
      @(posedge clk);
    end
    
    // Compare with expected results and count number of passes and errors
    for (int idx = 0; idx < NUM_TESTS; idx++) begin
      @(negedge clk);
      pass = 1;
      pass &= (exp_result    [WIDTH+1] == result);
      pass &= (exp_rem       [WIDTH+1] == rem);
      pass &= (exp_div_zero_f[WIDTH+1] == div_zero_f);
      
      if (pass) begin
        num_pass++;
      end else begin
        $error("Error, iteration: %0d, srca: 0x%0h, srcb: 0x%0h, is_signed: %0b, exp_result: 0x%0h, result: 0x%0h, exp_rem: %0b, rem: %0b, exp_div_zero_f: %0b, div_zero_f: %0b",
               idx, srca[WIDTH+1], srcb[WIDTH+1], is_signed[WIDTH+1], exp_result[WIDTH+1], result, exp_rem[WIDTH+1], rem, exp_div_zero_f[WIDTH+1], div_zero_f);
        num_errors++;
      end
    end // for
    
    $display("NUM_PASS: %0d, NUM_ERRORS: %0d", num_pass, num_errors);
    
    // Report results
    if (num_errors == 0) begin
      $display ("TEST PASS");
    end else begin
      $display ("TEST FAILED");
    end
    
//  $finish();
    $stop();
  end // initial (Check results)

  generate;
    genvar i;
    for (i = 0; i < (WIDTH+1); i++) begin : gen_tb_staging
      always_ff @(posedge clk) begin
        srca          [i+1] <= srca          [i];
        srcb          [i+1] <= srcb          [i];
        is_signed     [i+1] <= is_signed     [i];
        exp_result    [i+1] <= exp_result    [i];
        exp_rem       [i+1] <= exp_rem       [i];
        exp_div_zero_f[i+1] <= exp_div_zero_f[i];
      end
    end : gen_tb_staging
  endgenerate
  
endmodule

// Original TB for single cycle divider
//`timescale 1ns/1ns
//
//module tb_divider;
//  parameter int WIDTH = 64;
//  
//  logic clk;
//  
//  logic [WIDTH-1:0] srca;
//  logic [WIDTH-1:0] srcb;
//  logic [WIDTH-1:0] result;
//  logic [WIDTH-1:0] rem;
//  logic is_signed;
//  logic div_zero_f;
//  
//  logic [WIDTH-1:0] exp_result;
//  logic [WIDTH-1:0] exp_rem;
//  logic exp_div_zer_f;
//  
//  int num_pass;
//  int num_errors;
//  
//  // Instantiate DUT
//  divider #(
//    .WIDTH(WIDTH) 
//  )dut(
//    .srca(srca),
//    .srcb(srcb),
//    .is_signed(is_signed),
//    .result(result),
//    .rem(rem),
//    .div_zero_f(div_zero_f)
//  );
//  
//  initial begin
//    clk = 0;
//    forever begin
//      #5 clk = ~clk;
//    end
//  end
//  
//  initial begin
//    bit pass;
//    num_pass   = 0;
//	num_errors = 0;
//    
//    for (int idx = 0; idx < 1000; idx++) begin
//      @(posedge clk);
//      // Randomize data
//      srca      = $urandom();
//      srcb      = $urandom();
//      is_signed = $urandom();
//      // Expected result
//      exp_div_zer_f = 0;
//      if (srcb == 0) begin
//        exp_result    = '1;
//        exp_rem       = srca;
//        exp_div_zer_f = 1;
//      end else if (is_signed) begin
//        exp_result = $signed(srca) / $signed(srcb);
//        exp_rem    = $signed(srca) % $signed(srcb);
//      end else begin
//        exp_result = $unsigned(srca) / $unsigned(srcb);
//        exp_rem    = $unsigned(srca) % $unsigned(srcb);
//      end
//      // Check result
//      @(negedge clk);
//      pass = 1;
//      pass &= (exp_result    == result);
//      pass &= (exp_rem       == rem);
//      pass &= (exp_div_zer_f == exp_div_zer_f);
//      
//      if (pass) begin
//        num_pass++;
//      end else begin
//        $error("Error, iteration: %0d, srca: 0x%0h, srcb: 0x%0h, is_signed: %0b, exp_result: 0x%0h, result: 0x%0h, exp_rem: %0b, rem: %0b, exp_div_zer_f: %0b, div_zero_f: %0b", idx, srca, srcb, is_signed, exp_result, result, exp_rem, rem, exp_div_zer_f, div_zero_f);
//        num_errors++;
//      end
//      
//    end
//    
//    $display("NUM_PASS: %0d, NUM_ERRORS: %0d", num_pass, num_errors);
//    
//    if (num_errors == 0) begin
//      $display ("TEST PASS");
//    end else begin
//      $display ("TEST FAILED");
//    end
//    
//    $finish();
//    
//  end
//  
//  
//  
//endmodule
