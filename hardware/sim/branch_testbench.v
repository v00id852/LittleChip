`timescale 1ns/1ns
`include "Opcode.vh"

module branch_testbench;

  reg [31:0] rs1, rs2;
  reg [2:0] func;
  wire taken;

  BRANCH #(.DWIDTH(32)) uut (
    .rs1_in(rs1),
    .rs2_in(rs2),
    .func(func),
    .taken(taken) 
  );

  task check_taken;
    input [3:0] test_num;
    input expected, got;
    begin
      if (expected !== got) begin
        $display("FAIL - test %d, expected: %h, got: %h",
                test_num, expected, got);
        $finish;
      end else begin
        $display("PASS - test %d, got: %h", test_num, got);
      end
    end
  endtask

  task check_bge;
    begin
      $display("====CHECK BGE====");
      rs1 = 32'h0000_0001;
      rs2 = 32'h0000_0001;
      func = `FNC_BGE;
      #1 check_taken(1, 1'b1, taken);
      rs1 = 32'h0000_0001;
      rs2 = 32'h0000_0002;
      #1 check_taken(2, 1'b0, taken);
      rs1 = 32'h0000_0001;
      rs2 = 32'hffff_fff0;
      #1 check_taken(3, 1'b1, taken);
      rs1 = 32'h0000_0002;
      rs2 = 32'h0000_0001;
      #1 check_taken(4, 1'b1, taken);
    end
  endtask

    task check_bgeu;
    begin
      $display("====CHECK BGEU====");
      rs1 = 32'h0000_0001;
      rs2 = 32'h0000_0001;
      func = `FNC_BGEU;
      #1 check_taken(1, 1'b1, taken);
      rs1 = 32'h0000_0001;
      rs2 = 32'h0000_0002;
      #1 check_taken(2, 1'b0, taken);
      rs1 = 32'h0000_0001;
      rs2 = 32'hffff_fff0;
      #1 check_taken(3, 1'b0, taken);
      rs1 = 32'h0000_0002;
      rs2 = 32'h0000_0001;
      #1 check_taken(4, 1'b1, taken);
    end
  endtask

  initial begin
    check_bge();
    check_bgeu();
    $display("ALL BRANCH TESTS PASSED!");
    $finish;
  end

endmodule