// Module: ALU
// Disc: ALU supports AND,OR,Add,Subtract operations
`include "Opcode.vh"
`define ALU_CTRL_AND 4'b0000
`define ALU_CTRL_OR 4'b0001
`define ALU_CTRL_ADD 4'b0010
`define ALU_CTRL_SUB 4'b0110
`define ALU_CTRL_LE 4'b0111
`define ALU_CTRL_SLL 4'b1000
`define ALU_CTRL_NOR 4'b1100

module ALU #(
  parameter DWIDTH = 32
) (
  input [DWIDTH - 1:0] A,
  B,
  input [3:0] ctl,
  output [DWIDTH - 1:0] out,
  output zero
);

  reg [DWIDTH - 1:0] out;

  assign zero = (out == 0);

  always @(*) begin
    case (ctl)
      `ALU_CTRL_AND:  out = A & B;
      `ALU_CTRL_OR:   out = A | B;
      `ALU_CTRL_ADD:  out = A + B;
      `ALU_CTRL_SUB:  out = A - B;
      `ALU_CTRL_LE:   out = A < B ? 1 : 0;
      `ALU_CTRL_NOR:  out = ~(A | B);
      `ALU_CTRL_SLL:  out = A << (B & 32'h001f);
      default: out = 0;
    endcase
  end

endmodule

module ALUCtrl (
  input  [3:0] func,
  input  [1:0] alu_op,
  output [3:0] alu_ctrl
);

  reg [3:0] alu_ctrl;

  always @(*) begin
    case (alu_op)
      // ld/sd
      2'b00:   alu_ctrl = `ALU_CTRL_ADD;
      // beq
      2'b01:   alu_ctrl = `ALU_CTRL_SUB;
      // R-Type
      2'b10: begin
        case (func)
          4'b0000: alu_ctrl = `ALU_CTRL_ADD;
          4'b1000: alu_ctrl = `ALU_CTRL_SUB;
          4'b0111: alu_ctrl = `ALU_CTRL_AND;
          4'b0110: alu_ctrl = `ALU_CTRL_OR;
          {1'b0, `FNC_SLL} : alu_ctrl = `ALU_CTRL_SLL;
          default: alu_ctrl = `ALU_CTRL_ADD;
        endcase
      end
      default: alu_ctrl = `ALU_CTRL_ADD;
    endcase
  end

endmodule
