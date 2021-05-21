`timescale 1ns / 1ns

module alu_testbench;

  reg [31:0] A, B;
  reg [3:0] ctl;
  wire [31:0] out;
  wire zero;

  ALU #(
    .DWIDTH(32)
  ) uut (
    .A(A),
    .B(B),
    .ctl(ctl),
    .out(out),
    .zero(zero)
  );

  task check_alu_out;
    input [5:0] test_num;
    input [31:0] expected;
    input [31:0] got;
    begin
      if (expected !== got) begin
        $display("FAIL - test %d, got: %h, expected: %h", test_num, got, expected);
        $finish;
      end else begin
        $display("PASS - test %d, got: %h", test_num, got);
      end
    end
  endtask

  task check_alu_and;
    begin
      $display("====ALU And Test====");
      ctl = 0;
      A   = 32'h00000001;
      B   = 32'h0000001;
      #1 check_alu_out(1, 32'h00000001, out);
      A = 32'h0000_0000;
      B = 32'hffff_ffff;
      #1 check_alu_out(2, 32'h00000000, out);
      A = 32'hffff_ffff;
      B = 32'hffff_ffff;
      #1 check_alu_out(3, 32'hffff_ffff, out);
      A = 32'h0000_0000;
      B = 32'h0000_0000;
      #1 check_alu_out(4, 32'h0000_0000, out);
    end
  endtask

  task check_alu_add;
    begin
      $display("====ALU Add Test====");
      A   = 1;
      B   = 1;
      ctl = 2;
      #1 check_alu_out(1, A + B, out);
      A = 32'hffffffff;
      B = 1;
      #1 check_alu_out(2, 0, out);
    end
  endtask

  task check_alu_or;
    begin
      $display("====ALU Or Test====");
      ctl = 1;
      A   = 32'h0000_0000;
      B   = 32'h0000_0001;
      #1 check_alu_out(1, 32'h0000_0001, out);
      A = 32'h0000_0000;
      B = 32'hffff_ffff;
      #1 check_alu_out(2, 32'hffff_ffff, out);
      A = 32'hffff_ffff;
      B = 32'hffff_ffff;
      #1 check_alu_out(3, 32'hffff_ffff, out);
      A = 32'h0000_0000;
      B = 32'h0000_0000;
      #1 check_alu_out(4, 32'h0000_0000, out);
    end
  endtask

  task check_alu_sub;
    begin
      $display("====ALU Minus Test====");
      ctl = 6;
      A   = 32'h0000_00ff;
      B   = 32'h0000_0001;
      #1 check_alu_out(1, 32'h0000_00fe, out);
      A = 32'h0000_0000;
      B = 32'h0000_0001;
      #1 check_alu_out(2, 32'hffff_ffff, out);
      A = 32'h0000_0001;
      B = 32'h0000_0001;
      #1 check_alu_out(3, 32'h0000_0000, out);
    end
  endtask

  task check_alu_less;
    begin
      $display("====ALU Less Test===");
      ctl = 7;
      A   = 32'h0000_0001;
      B   = 32'h0000_0000;
      #1 check_alu_out(1, 0, out);
      A = 32'h0000_0000;
      B = 32'h0000_0001;
      #1 check_alu_out(2, 1, out);
      A = 32'hffff_ffff;
      B = 32'h0000_0000;
      #1 check_alu_out(3, 0, out);
    end
  endtask

  task check_alu_nor;
    begin
      $display("====ALU Nor Test====");
      ctl = 12;
      A   = 32'h0000_0000;
      B   = 32'hffff_ffff;
      #1 check_alu_out(1, 32'h0000_0000, out);
      A = 32'hffff_ffff;
      B = 32'hffff_ffff;
      #1 check_alu_out(2, 32'h0000_0000, out);
      A = 32'h0000_0000;
      B = 32'h0000_0000;
      #1 check_alu_out(3, 32'hffff_ffff, out);
      A = 32'hffff_ffff;
      B = 32'h0000_0000;
      #1 check_alu_out(4, 32'h0000_0000, out);
    end
  endtask

  initial begin
    check_alu_and();
    check_alu_or();
    check_alu_add();
    check_alu_sub();
    check_alu_less();
    check_alu_sltu();
    check_alu_nor();
    // check_alu_sll();
    // check_alu_xor();
    // check_alu_srl();
    // check_alu_sra();
    $display("ALL ALU TESTS PASSED!");
  end

endmodule
