module CYCLE_COUNTER #(
  parameter DWIDTH = 32
) (
  input clk,
  input rst,
  output [DWIDTH - 1:0] cycle
);

  wire [DWIDTH - 1:0] cycle_value, cycle_next;

  REGISTER_R #(.N(DWIDTH), .INIT(0)) cycle_reg (
    .clk(clk),
    .rst(rst),
    .q(cycle_value),
    .d(cycle_next)
  );

  assign cycle_next = cycle_value + 1;
  
endmodule