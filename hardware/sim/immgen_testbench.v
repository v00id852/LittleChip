`timescale 1ns / 1ns

module immgen_testbench ();

  reg  [31:0] inst;
  wire [31:0] imm_gen;

  IMM_GEN uut (
    .inst_in(inst),
    .imm_out(imm_gen)
  );

  task check_imm;
    input [10:0] test_index;
    input [31:0] expected;
    input [31:0] imm_value;
    begin

      if (expected !== imm_value) begin
        $display("FAIL - test %d, got: %h, expected: %h", test_index, imm_value, expected);
        $finish;
      end else begin
        $display("PASS - test %d, got: %h", test_index, expected);
      end
    end
  endtask

  task test_I_inst;
    begin
      $display("====Test I-type instruction====");
      // I jalr
      inst = {12'b000000000001, 13'd0, 7'b1100111};
      #10;
      check_imm(1, 32'h1, imm_gen);
      // I jalr negative
      inst = {12'b100000000001, 13'd0, 7'b1100111};
      #10;
      check_imm(2, 32'hFFFFF801, imm_gen);
      // I lb
      inst = {12'b000000000001, 13'd0, 7'b0000011};
      #10;
      check_imm(3, 32'h1, imm_gen);

      // I lb negative
      inst = {12'b100000000001, 13'd0, 7'b0000011};
      #10;
      check_imm(4, 32'hFFFFF801, imm_gen);

      // I addi
      inst = {12'b000000000001, 13'd0, 7'b0010011};
      #10;
      check_imm(5, 32'h1, imm_gen);

      // I addi negative
      inst = {12'b100000000001, 13'd0, 7'b0010011};
      #10;
      check_imm(6, 32'hFFFFF801, imm_gen);
    end
  endtask

  task test_B_inst;
    begin
      $display("====Test B-type Instruction====");
      // B beq
      inst = {7'b0_111010, 13'd0, 5'b1010_1, 7'b1100011};
      #10;
      check_imm(1, {19'b0000000000000000000, 13'b0_1_111010_1010_0}, imm_gen);

      // B beq negative
      inst = {7'b1111010, 13'd0, 5'b10101, 7'b1100011};
      #10;
      check_imm(2, {19'b1111111111111111111, 13'b1_1_111010_1010_0}, imm_gen);
    end
  endtask

  task test_S_inst;
    begin
      $display("====Test S-type Instruction====");
      // S sb
      inst = {7'b0111111, 13'd0, 5'b00000, 7'b0100011};
      #10;
      check_imm(1, {20'h00000, 12'b0111111_00000}, imm_gen);

      // S sb negative
      inst = {7'b1111111, 13'd0, 5'b00000, 7'b0100011};
      #10;
      check_imm(2, {20'hFFFFF, 12'b1111111_00000}, imm_gen);
    end
  endtask

  task test_U_inst;
    begin
      $display("====Test U-type Instruction====");
      // U lui
      inst = {20'd1, 5'd0, 7'b0110111};
      #10;
      check_imm(1, {20'd1, 12'd0}, imm_gen);

      // U auipc;
      inst = {20'd1, 5'd0, 7'b0010111};
      #10;
      check_imm(2, {20'd1, 12'd0}, imm_gen);
    end
  endtask

  task test_J_inst;
    begin
      $display("====Test J-type Instruction====");
      // J jal
      inst = {1'b0, 10'b1111111111, 1'b0, 8'b01010101, 5'd0, 7'b1101111};
      #10;
      check_imm(1, {11'd0, 21'b0_01010101_0_1111111111_0}, imm_gen);
      // J jal negative
      inst = {1'b1, 10'b1111111111, 1'b0, 8'b01010101, 5'd0, 7'b1101111};
      #10;
      check_imm(2, {11'hfff, 21'b1_01010101_0_1111111111_0}, imm_gen);
    end
  endtask


  initial begin
    $dumpfile("immgen_testbench.vcd");
    $dumpvars;
    test_I_inst();
    test_B_inst();
    test_U_inst();
    test_S_inst();
    test_J_inst();
    $display("ALL IMM_GEN TESTS PASSED!");
    $finish;
  end


endmodule
