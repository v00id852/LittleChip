`timescale 1ns/1ns

module synchronizer #(parameter WIDTH = 1) (
  input [WIDTH-1:0] async_signal,
  input clk,
  output [WIDTH-1:0] sync_signal
);

  wire [WIDTH-1: 0] inter_signal;
  
  REGISTER #(.N(WIDTH)) r1 (
    .clk(clk),
    .d(async_signal),
    .q(inter_signal)
  );

  REGISTER #(.N(WIDTH)) r2 (
    .clk(clk),
    .d(inter_signal),
    .q(sync_signal)
  );
endmodule
