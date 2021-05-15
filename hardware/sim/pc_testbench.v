`timescale 1ns / 1ns

module pc_testbench ();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20;
  parameter CPU_CLOCK_FREQ = 1_000_000_000 / CPU_CLOCK_PERIOD;

  initial clk = 0;
  always #(CPU_CLOCK_PERIOD / 2) clk = ~clk;

  reg pc_sel;
  reg [31:0] pc_new_val;
  wire [31:0] pc_val;

  localparam RESET_ADDR = 32'h4000_0000;

  PC #(
    .AWIDTH(32),
    .RESET_PC_VAL(RESET_ADDR)
  ) uut (
    .clk(clk),
    .rst(rst),
    .pc_sel_in(pc_sel),
    .pc_new_in(pc_new_val),
    .pc_out(pc_val)
  );

  task check_pc_val;
    input [31:0] expected_value;
    input [31:0] pc_value;
    input [10:0] test_num;
    begin
      if (expected_value !== pc_value) begin
        $display("FAIL - test %d, got: %h, expected: %h", test_num, pc_value, expected_value);
        $finish;
      end else begin
        $display("PASS - test %d, got: %h", test_num, expected_value);
      end
    end
  endtask


  initial begin
    $dumpfile("if_testbench.vcd");
    $dumpvars;

    rst = 1;
    pc_sel = 0;

    // Hold reset for a while
    repeat (10) @(posedge clk);

    rst = 0;
    // Test pc reset value
    check_pc_val(RESET_ADDR, pc_val, 1);
    // Test pc plus 4
    repeat (2) @(posedge clk);
    #1 check_pc_val(RESET_ADDR + 8, pc_val, 2);
    // Test select new pc value.
    pc_sel = 1;
    pc_new_val = 32'h2000_0000;

    @(posedge clk);
    #1 check_pc_val(32'h2000_0000, pc_val, 3);

    pc_sel = 0;

    @(posedge clk) #1 check_pc_val(32'h2000_0000 + 4, pc_val, 4);

    $display("ALL IF TESTS PASSED!");
    $finish();
  end

  initial begin
    #1000;
    $display("Failed: timing out");
    $finish();
  end

endmodule
