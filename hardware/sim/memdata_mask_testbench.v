`timescale 1ns/1ns

`include "../src/riscv_core/Opcode.vh"

module memdata_mask_testbench;

  reg [31:0] data_in;
  reg [2:0] func;
  reg [1:0] byte_addr;
  wire[31:0] data_out;

  MEM_MASK #(.DATA_WIDTH(32)) uut (
    .data_in(data_in),
    .inst_func_in(func),
    .byte_addr_in(byte_addr),
    .data_out(data_out)
  );

  task check_data_out;
    input [3:0] test_num;
    input [31:0] expected, got;
    begin
      if (expected !== got) begin
        $display("FAIL - test %d, expected: %h, got: %h",
                test_num, expected, got);
        $finish;
      end else begin
        $display("PASS - test %d, got: %h",
                test_num, got);
      end
    end
  endtask

  task check_lb;
    begin
      $display("====Check LB====");
      data_in = 32'hdeadbeef;
      func = `FNC_LB;
      byte_addr = 0;
      #1 check_data_out(1, 32'hffffffef, data_out);
      byte_addr = 1;
      #1 check_data_out(2, 32'hffffffbe, data_out);
      byte_addr = 2;
      #1 check_data_out(3, 32'hffffffad, data_out);
      byte_addr = 3;
      #1 check_data_out(4, 32'hffffffde, data_out);
    end
  endtask

  task check_lh;
    begin
      $display("====Check LH====");
      data_in = 32'hdeadbeef;
      func = `FNC_LH;
      byte_addr = 0;
      #1 check_data_out(1, 32'hffffbeef, data_out);
      byte_addr = 1;
      #1 check_data_out(2, 32'hffffadbe, data_out);
      byte_addr = 2;
      #1 check_data_out(3, 32'hffffdead, data_out);
      byte_addr = 3;
      #1 check_data_out(4, 32'hffffdead, data_out);
    end
  endtask

  task check_lbu;
    begin
      $display("====Check LBU====");
      data_in = 32'hdeadbeef;
      func = `FNC_LBU;
      byte_addr = 0;
      #1 check_data_out(1, 32'h000000ef, data_out);
      byte_addr = 1;
      #1 check_data_out(2, 32'h000000be, data_out);
      byte_addr = 2;
      #1 check_data_out(3, 32'h000000ad, data_out);
      byte_addr = 3;
      #1 check_data_out(4, 32'h000000de, data_out);
    end
  endtask

  task check_lhu;
    begin
      $display("====Check LHU====");
      data_in = 32'hdeadbeef;
      func = `FNC_LHU;
      byte_addr = 0;
      #1 check_data_out(1, 32'h0000beef, data_out);
      byte_addr = 1;
      #1 check_data_out(2, 32'h0000adbe, data_out);
      byte_addr = 2;
      #1 check_data_out(3, 32'h0000dead, data_out);
      byte_addr = 3;
      #1 check_data_out(4, 32'h0000dead, data_out);
    end
  endtask

  initial begin
    $dumpfile("memmask_testbench.vcd");
    $dumpvars;
    check_lb();
    check_lbu();
    check_lh();
    check_lhu();
    $display("ALL MEMMASK TESTS PASSED!");
    $finish;
  end

endmodule