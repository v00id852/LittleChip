`include "Opcode.vh"

module HAZARD_DETECTION (
  input clk,
  input [6:0] opcode,
  output ctrl_id_reg_flush,
  output ctrl_zero_sel
);

  wire inst_flush_value;

  // Imem use synchronous ram, so the flush control line output should use a register to 
  // be synchronized with the instruction.
  REGISTER #(.N(1)) inst_flush_reg (
    .clk(clk),
    .d(inst_flush_value),
    .q(ctrl_id_reg_flush)
  );
  
  assign inst_flush_value = (opcode == `OPC_JAL) || (opcode == `OPC_JALR);
  // NOP
  assign ctrl_zero_sel = opcode == 6'b0;

endmodule