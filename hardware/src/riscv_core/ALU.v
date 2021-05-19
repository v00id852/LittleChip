// Module: ALU
// Disc: ALU supports AND,OR,Add,Subtract operations
`include "Opcode.vh"
`include "ALUCtrlCode.vh"

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
      `ALU_CTRL_AND: out = A & B;
      `ALU_CTRL_OR: out = A | B;
      `ALU_CTRL_ADD: out = A + B;
      `ALU_CTRL_SUB: out = A - B;
      `ALU_CTRL_SLT: out = $signed(A) < $signed(B) ? 1 : 0;
      `ALU_CTRL_SLTU: out = A < B ? 1 : 0;
      `ALU_CTRL_NOR: out = ~(A | B);
      `ALU_CTRL_SLL: out = A << (B & 32'h001f);
      `ALU_CTRL_XOR: out = A ^ B;
      `ALU_CTRL_SRL: out = A >> (B & 32'h001f);
      `ALU_CTRL_SRA: out = $signed(A) >>> (B & 32'h001f);
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
          {1'b0, `FNC_AND} : alu_ctrl = `ALU_CTRL_AND;
          {1'b0, `FNC_OR} : alu_ctrl = `ALU_CTRL_OR;
          {1'b0, `FNC_XOR} : alu_ctrl = `ALU_CTRL_XOR;
          {1'b0, `FNC_SLL} : alu_ctrl = `ALU_CTRL_SLL;
          {1'b0, `FNC_SLT} : alu_ctrl = `ALU_CTRL_SLT;
          {1'b0, `FNC_SLTU} : alu_ctrl = `ALU_CTRL_SLTU;
          {1'b0, `FNC_SRL_SRA} : alu_ctrl = `ALU_CTRL_SRL;
          {1'b1, `FNC_SRL_SRA} : alu_ctrl = `ALU_CTRL_SRA;
          default: alu_ctrl = `ALU_CTRL_ADD;
        endcase
      end
      // I-Type
      2'b11: begin
        case (func[2:0])
          `FNC_ADD_SUB: alu_ctrl = `ALU_CTRL_ADD;
          `FNC_SLT:     alu_ctrl = `ALU_CTRL_SLT;
          `FNC_SLTU:    alu_ctrl = `ALU_CTRL_SLTU;
          `FNC_XOR:     alu_ctrl = `ALU_CTRL_XOR;
          `FNC_OR:      alu_ctrl = `ALU_CTRL_OR;
          `FNC_AND:     alu_ctrl = `ALU_CTRL_AND;
          `FNC_SLL:     alu_ctrl = `ALU_CTRL_SLL;
          `FNC_SRL_SRA: begin
            if (func[3] == 1'b0) alu_ctrl = `ALU_CTRL_SRL;
            else alu_ctrl = `ALU_CTRL_SRA;
          end
          default:      alu_ctrl = `ALU_CTRL_ADD;
        endcase
      end
      default: alu_ctrl = `ALU_CTRL_ADD;
    endcase
  end

endmodule
