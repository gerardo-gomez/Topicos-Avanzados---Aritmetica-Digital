`timescale 1ns/1ns

module tb_csa;
  parameter int WIDTH  = 4;
  parameter int NUM_IN = 8;  // Number of input operands
  
  logic clk;
  
  logic [NUM_IN-1:0][WIDTH-1:0] tree_in;
  logic             [WIDTH-1:0] result;
  logic                         cout;
  
  logic [WIDTH-1:0] exp_result;
  logic             exp_cout;
  
  int num_pass;
  int num_errors;
  
  // Instantiate DUT
  csa_adder #(
    .WIDTH (WIDTH ),
    .NUM_IN(NUM_IN)
  ) dut (
    .tree_in(tree_in),
    .result (result ),
    .cout   (cout   )
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
      {exp_cout, exp_result} = '0;
      for (int operand = 0; operand < NUM_IN; operand++) begin
      // Randomize data
        tree_in[operand]       = $urandom();
      // Expected result
        {exp_cout, exp_result} = ({exp_cout, exp_result} + {1'b0, tree_in[operand]});
      end
      // Check result
      @(negedge clk);
      pass = 1;
      pass &= (exp_result == result);
      pass &= (exp_cout   == cout);
      
      if (pass) begin
        num_pass++;
      end else begin
        $error("Error, iteration: %0d, tree_in: %p, exp_result: 0x%0h, result: 0x%0h, exp_cout: %0b, cout: %0b", idx, tree_in, exp_result, result, exp_cout, cout);
        num_errors++;
      end
      
    end
    
    $display("NUM_PASS: %0d, NUM_ERRORS: %0d", num_pass, num_errors);
    
    if (num_errors == 0) begin
      $display ("TEST PASS");
    end else begin
      $display ("TEST FAILED");
    end
    
    $stop();
//  $finish();
  end

endmodule