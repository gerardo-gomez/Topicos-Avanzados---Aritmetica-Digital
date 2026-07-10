`timescale 1ns/1ns

module tb_adder_sat;
  parameter int WIDTH = 32;
  
  logic clk;
  
  logic [WIDTH-1:0] srca;
  logic [WIDTH-1:0] srcb;
  logic             sat_to_max;
  logic [WIDTH-1:0] max_sat_value;
  logic             sat_to_min;
  logic [WIDTH-1:0] min_sat_value;
  logic [WIDTH-1:0] tmp_sat_value;
  logic [WIDTH-1:0] result;
  logic cin;
  logic is_signed;
  
  logic [WIDTH:0]   tmp_exp_result;
  logic [WIDTH-1:0] exp_result;
  
  int num_pass;
  int num_errors;
  
  // Instantiate DUT
  adder_sat #(
    .WIDTH(WIDTH) 
  )dut(
    .srca(srca),
    .srcb(srcb),
    .sat_to_max(sat_to_max),
    .max_sat_value(max_sat_value),
    .sat_to_min(sat_to_min),
    .min_sat_value(min_sat_value),
    .cin(cin),
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
      cin       = $urandom();
      is_signed = $urandom();
      sat_to_max = $urandom();
      sat_to_min = $urandom();
      max_sat_value = $urandom();
      min_sat_value = $urandom();
      if (max_sat_value == min_sat_value) begin
        min_sat_value[0] = ~min_sat_value[0];
      end
      if (is_signed) begin
        tmp_exp_result = ({srca[WIDTH-1], srca} + {srcb[WIDTH-1], srcb} + cin);
        if ($signed(min_sat_value) > $signed(max_sat_value)) begin
          tmp_sat_value = min_sat_value;
          min_sat_value = max_sat_value;
          max_sat_value = tmp_sat_value;
        end
      end else begin
        tmp_exp_result = ({1'b0, srca} + {1'b0, srcb} + cin);
        if ($unsigned(min_sat_value) > $unsigned(max_sat_value)) begin
          tmp_sat_value = min_sat_value;
          min_sat_value = max_sat_value;
          max_sat_value = tmp_sat_value;
        end
      end
      // Expected result
      if (is_signed) begin
        if (sat_to_max && ($signed(tmp_exp_result) > $signed(max_sat_value))) begin
          tmp_exp_result = max_sat_value;
        end else if (sat_to_min && ($signed(tmp_exp_result) < $signed(min_sat_value))) begin
          tmp_exp_result = min_sat_value;
        end
      end else begin
        if (sat_to_max && ($unsigned(tmp_exp_result) > $unsigned(max_sat_value))) begin
          tmp_exp_result = max_sat_value;
        end else if (sat_to_min && ($unsigned(tmp_exp_result) < $unsigned(min_sat_value))) begin
          tmp_exp_result = min_sat_value;
        end
      end
      exp_result = tmp_exp_result[WIDTH-1:0];
      // Check result
      @(negedge clk);
      pass = 1;
      pass &= (exp_result == result);
      
      if (pass) begin
        num_pass++;
      end else begin
        $error("Error, iteration: %0d, srca: 0x%0h, srcb: 0x%0h, cin: %0b, is_signed: %0b, sat_to_max: %0b, sat_to_min: %0b, max_sat_value: 0x%0h, min_sat_value: 0x%0h, exp_result: 0x%0h, result: 0x%0h", idx, srca, srcb, cin, is_signed, sat_to_max, sat_to_min, max_sat_value, min_sat_value, exp_result, result);
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