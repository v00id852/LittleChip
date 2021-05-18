`timescale 1ns / 1ns

module aluctrl_testbench;

  reg  [3:0] func;
  reg  [1:0] op;
  wire [3:0] ctrl_out;

  ALUCtrl uut (
    .func(func),
    .alu_op(op),
    .alu_ctrl(ctrl_out)
  );

  task check_alu_ctrl;
    input [3:0] test_num;
    input [3:0] expected_ctrl;
    input [3:0] got_ctrl;
    begin
      if (expected_ctrl !== got_ctrl) begin
        $display("FAIL - test %d, expected: %b, got: %b", test_num, expected_ctrl, got_ctrl);
        $finish;
      end else begin
        $display("PASS - test %d, got: %b", test_num, got_ctrl);
      end
    end
  endtask

  task check_add_op;
    begin
      $display("====Check Add Operation====");
      op   = 2'b00;
      func = 4'b0000;
      #1 check_alu_ctrl(1, 4'b0010, ctrl_out);
      op   = 2'b10;
      func = 4'b0000;
      #1 check_alu_ctrl(2, 4'b0010, ctrl_out);
    end
  endtask

  task check_subtract_op;
    begin
      $display("====Check Subtract Operation====");
      op   = 2'b01;
      func = 4'b0000;
      #1 check_alu_ctrl(1, 4'b0110, ctrl_out);
      op   = 2'b10;
      func = 4'b0010;
      #1 check_alu_ctrl(2, 4'b0110, ctrl_out);
    end
  endtask

  task check_AND_op;
    begin
      $display("====Check AND Operation====");
      op   = 2'b10;
      func = 4'b0100;
      #1 check_alu_ctrl(1, 4'b0000, ctrl_out);
    end
  endtask

  task check_OR_op;
    begin
      $display("====Check OR Operation====");
      op   = 2'b10;
      func = 4'b0101;
      #1 check_alu_ctrl(1, 4'b0001, ctrl_out);
    end
  endtask

  task check_LESS_op;
    begin
      $display("====Check LESS Operation====");
      op   = 2'b10;
      func = 4'b1010;
      #1 check_alu_ctrl(1, 4'b0111, ctrl_out);
    end
  endtask

  initial begin
    check_add_op();
    check_subtract_op();
    check_AND_op();
    check_OR_op();
    check_LESS_op();
    $display("ALL ALUCTRL TESTS PASSED!");
    $finish;
  end

endmodule
