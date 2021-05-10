`timescale 1ns / 1ns

module IF #(
  parameter AWIDTH = 32,
  parameter RESET_PC_VAL = {AWIDTH{1'b0}}
) (
  input clk,
  input rst,
  input pc_sel,  // select which is the new pc value, old_pc + 4 or pc_new_val
  input [AWIDTH - 1 : 0] pc_new_val,  // the new pc value from ALU
  output [AWIDTH - 1 : 0] pc_val
);

  wire [AWIDTH - 1 : 0] pc_value, pc_next;
  wire pc_rst;

  REGISTER_R #(
    .N(AWIDTH),
    .INIT(RESET_PC_VAL)
  ) pc (
    .clk(clk),
    .rst(rst),
    .d  (pc_next),
    .q  (pc_value)
  );

  // if pc_sel is asserted, the next pc value will be pc_new_val, 
  // otherwise it will be the old pc value plus 4
  assign pc_next = pc_sel ? pc_new_val : pc_value + 4;
  assign pc_val  = pc_value;

endmodule
