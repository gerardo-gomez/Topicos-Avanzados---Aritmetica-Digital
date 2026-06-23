`timescale 1ns/1ns

module tb_adder;
  parameter int WIDTH = 4;
  
  logic clk;
  
  logic [WIDTH-1:0] srca;
  logic [WIDTH-1:0] srcb;
  logic [WIDTH-1:0] result;
  logic cin;
  logic is_signed;
  logic cout;
  logic zero_f;
  logic ov_f;
  
  logic [WIDTH-1:0] exp_result;
  logic exp_cout;
  logic exp_zero_f;
  logic exp_ov_f;
  
  int num_pass;
  int num_errors;
  
  // Instantiate DUT
  adder #(
    .WIDTH(WIDTH) 
  )dut(
    .srca(srca),
    .srcb(srcb),
    .cin(cin),
    .is_signed(is_signed),
    .result(result),
    .cout(cout),
    .zero_f(zero_f),
    .ov_f(ov_f)
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
      cin       = $urandom();
      is_signed = $urandom();
      // Expected result
      {exp_cout, exp_result} = ({1'b0, srca} + {1'b0, srcb} + {{(WIDTH-1){1'b0}},cin});
      exp_zero_f             = (exp_result == 0);
      if (is_signed) begin
        exp_ov_f = ((srca[WIDTH-1] == srcb[WIDTH-1]) && (srca[WIDTH-1] != exp_result[WIDTH-1]));
      end else begin
        exp_ov_f = exp_cout;
      end
      // Check result
      @(negedge clk);
      pass = 1;
      pass &= (exp_result == result);
      pass &= (exp_cout   == cout);
      pass &= (exp_zero_f == zero_f);
      pass &= (exp_ov_f   == ov_f);
      
      if (pass) begin
        num_pass++;
      end else begin
        $error("Error, iteration: %0d, srca: 0x%0h, srcb: 0x%0h, cin: %0b, is_signed: %0b, exp_result: 0x%0h, result: 0x%0h, exp_cout: %0b, cout: %0b, exp_zero_f: %0b, zero_f: %0b, exp_ov_f: %0b, ov_f: %0b", idx, srca, srcb, cin, is_signed, exp_result, result, exp_cout, cout, exp_zero_f, zero_f, exp_ov_f, ov_f);
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
  
  // Assertions
  logic [WIDTH-1:0] sva_result;
  logic             sva_cout;

  assign {sva_cout, sva_result} = srca + srcb + cin;

  result_check: assert property (@(negedge clk) disable iff (ov_f)
    (result === sva_result)
  ) else $error("Adder result mismatch (signed = %0d): A + B + Cin = 0x%0h + 0x%0h + 0x%0h = 0x%0h (expected 0x%0h)",
                is_signed, srca, srcb, cin, result, sva_result);

  cout_check: assert property (@(negedge clk)
    (cout === sva_cout)
  ) else $error("Carry out mismatch (signed = %0d): A + B + Cin = 0x%0h + 0x%0h + 0x%0h = 0x%0h (expected 0x%0h), cout = %0d (expected %0d)",
                is_signed, srca, srcb, cin, result, sva_result, cout, sva_cout);

  zero_flag_check: assert property (@(negedge clk)
    (zero_f === (result == 0))
  ) else $error("Zero flag mismatch: result = 0x%0h, zero_f = %0d (expected %0d)",
                result, zero_f, (result == 0));

//overflow_flag_check: assert property (@(negedge clk)
//  ((ov_f) |-> ( ( is_signed & (dut.c[WIDTH-1] != dut.c[(WIDTH-1)+1]))
//              | (~is_signed & cout)))
//) else $error("Overflow flag mismatch (signed = %0d): cout = %0d, cin[MSB] = %0d, cout[MSB] = %0d, ov_f = %0d",
//              is_signed, cout, dut.c[WIDTH-1], dut.c[(WIDTH-1)+1], ov_f);
  
endmodule