module INST_COUNTER #(
  parameter DWIDTH = 32
) (
  input clk,
  input rst,
  input [6:0] opcode,
  output [DWIDTH - 1:0] counter_out
);

  wire [DWIDTH - 1:0] counter_value, counter_next;

  REGISTER_R #(
    .N(DWIDTH),
    .INIT(0)
  ) counter_reg (
    .clk(clk),
    .rst(rst),
    .d  (counter_next),
    .q  (counter_value)
  );

  assign counter_out  = counter_value;
  assign counter_next = (opcode == 6'd0) ? counter_value : counter_value + 1;

endmodule
