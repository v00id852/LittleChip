`timescale 1ns / 1ns

module PC #(
  parameter PC_WIDTH = 32,
  parameter RESET_PC_VAL = {AWIDTH{1'b0}}
) (
  input clk,
  input rst,
  input pc_sel_in,  // select which is the new pc value, old_pc + 4 or pc_new_val
  input pc_en,
  input [PC_WIDTH - 1 : 0] pc_new_in,  // the new pc value from ALU
  output [PC_WIDTH - 1 : 0] pc_out
);

  wire [PC_WIDTH - 1 : 0] pc_value, pc_next;
  wire pc_rst;

  REGISTER_R_CE #(
    .N(PC_WIDTH),
    .INIT(RESET_PC_VAL)
  ) pc (
    .clk(clk),
    .rst(rst),
    .ce (pc_en),
    .d  (pc_next),
    .q  (pc_value)
  );

  // if pc_sel is asserted, the next pc value will be pc_new_val, 
  // otherwise it will be the old pc value plus 4
  assign pc_next = pc_sel_in ? pc_new_in : pc_value + 4;
  assign pc_out  = pc_value;

endmodule
