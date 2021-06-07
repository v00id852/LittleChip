// Module: ALU
// Disc: ALU supports AND,OR,Add,Subtract operations
`include "Opcode.vh"
`include "ALUCtrlCode.vh"

`define ALU_OUT_SEL_ADD_SUB 2'b00
`define ALU_OUT_SEL_BITWISE 2'b01
`define ALU_OUT_SEL_LESS 2'b10
`define ALU_OUT_SEL_SHIFT 2'b11

`define ALU_BITWISE_NONE 2'b00
`define ALU_BITWISE_AND 2'b01
`define ALU_BITWISE_OR 2'b10
`define ALU_BITWISE_XOR 2'b11

`define ALU_SHIFT_NONE 2'b00
`define ALU_SHIFT_SLL 2'b01
`define ALU_SHIFT_SRL 2'b10
`define ALU_SHIFT_SRA 2'b11

module ALU #(
  parameter DWIDTH = 32
) (
  input [DWIDTH - 1:0] A,
  input [DWIDTH - 1:0] B,
  input [1:0] ctrl_alu_out_sel,
  input [1:0] ctrl_bitwise_sel,
  input [1:0] ctrl_shift_sel,
  input ctrl_sub_less_sel,
  input ctrl_slt_unsigned_sel,
  output reg [DWIDTH - 1:0] out
);

  wire [DWIDTH - 1:0] less;
  wire [DWIDTH - 1:0] add_sub_out;

  reg [DWIDTH - 1:0] shift;
  reg [DWIDTH - 1:0] bitwise_out;

  always @(*) begin
    case (ctrl_bitwise_sel)
      `ALU_BITWISE_AND: bitwise_out = A & B;  // AND
      `ALU_BITWISE_OR: bitwise_out = A | B;  // OR
      `ALU_BITWISE_XOR: bitwise_out = A ^ B;  // XOR
      default: bitwise_out = 0;
    endcase
  end

  assign less        = (A[31] === B[31]) ? add_sub_out[31] : ctrl_slt_unsigned_sel ? B[31] : A[31];
  assign add_sub_out = A + ((ctrl_sub_less_sel) ? (~B + 32'd1) : B);

  wire [4:0] offset = B[4:0];

  always @(*) begin
    case (ctrl_shift_sel)
      `ALU_SHIFT_SLL:   shift = A << offset;
      `ALU_SHIFT_SRL:   shift = A >> offset;
      `ALU_SHIFT_SRA:   shift = $signed(A) >>> offset;
      default: shift = 0;
    endcase
  end

  always @(*) begin
    case (ctrl_alu_out_sel)
      `ALU_OUT_SEL_ADD_SUB: out = add_sub_out;
      `ALU_OUT_SEL_BITWISE: out = bitwise_out;
      `ALU_OUT_SEL_LESS: out = less;
      `ALU_OUT_SEL_SHIFT: out = shift;
      default: out = 0;
    endcase
  end

endmodule

module ALUCtrl (
  input [3:0] func,
  input [1:0] alu_op,
  output reg [1:0] ctrl_alu_out_sel,
  output reg [1:0] ctrl_bitwise_sel,
  output reg [1:0] ctrl_shift_sel,
  output reg ctrl_sub_less_sel,
  output reg ctrl_slt_unsigned_sel
);

  reg [3:0] alu_ctrl;

  always @(*) begin
    case (alu_op)
      // ld/sd
      2'b00:   alu_ctrl = `ALU_CTRL_ADD;
      // B-Type
      2'b01: begin
        case (func[2:0])
          `FNC_BLT:  alu_ctrl = `ALU_CTRL_SLT;
          `FNC_BGE:  alu_ctrl = `ALU_CTRL_SLT;
          `FNC_BLTU: alu_ctrl = `ALU_CTRL_SLTU;
          `FNC_BGEU: alu_ctrl = `ALU_CTRL_SLTU;
          default:   alu_ctrl = `ALU_CTRL_SUB;
        endcase
      end
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

  always @(*) begin
    case (alu_ctrl)
      `ALU_CTRL_AND:  ctrl_alu_out_sel = `ALU_OUT_SEL_BITWISE;
      `ALU_CTRL_OR:   ctrl_alu_out_sel = `ALU_OUT_SEL_BITWISE;
      `ALU_CTRL_XOR:  ctrl_alu_out_sel = `ALU_OUT_SEL_BITWISE;
      `ALU_CTRL_ADD:  ctrl_alu_out_sel = `ALU_OUT_SEL_ADD_SUB;
      `ALU_CTRL_SUB:  ctrl_alu_out_sel = `ALU_OUT_SEL_ADD_SUB;
      `ALU_CTRL_SLT:  ctrl_alu_out_sel = `ALU_OUT_SEL_LESS;
      `ALU_CTRL_SLTU: ctrl_alu_out_sel = `ALU_OUT_SEL_LESS;
      `ALU_CTRL_SLL:  ctrl_alu_out_sel = `ALU_OUT_SEL_SHIFT;
      `ALU_CTRL_SRL:  ctrl_alu_out_sel = `ALU_OUT_SEL_SHIFT;
      `ALU_CTRL_SRA:  ctrl_alu_out_sel = `ALU_OUT_SEL_SHIFT;
    endcase
  end


  always @(*) begin
    case (alu_ctrl)
      `ALU_CTRL_AND:  ctrl_bitwise_sel = `ALU_BITWISE_AND;
      `ALU_CTRL_OR:   ctrl_bitwise_sel = `ALU_BITWISE_OR;
      `ALU_CTRL_XOR:  ctrl_bitwise_sel = `ALU_BITWISE_XOR;
      `ALU_CTRL_ADD:  ctrl_bitwise_sel = `ALU_BITWISE_NONE;
      `ALU_CTRL_SUB:  ctrl_bitwise_sel = `ALU_BITWISE_NONE;
      `ALU_CTRL_SLT:  ctrl_bitwise_sel = `ALU_BITWISE_NONE;
      `ALU_CTRL_SLTU: ctrl_bitwise_sel = `ALU_BITWISE_NONE;
      `ALU_CTRL_SLL:  ctrl_bitwise_sel = `ALU_BITWISE_NONE;
      `ALU_CTRL_SRL:  ctrl_bitwise_sel = `ALU_BITWISE_NONE;
      `ALU_CTRL_SRA:  ctrl_bitwise_sel = `ALU_BITWISE_NONE;
    endcase
  end

  always @(*) begin
    case (alu_ctrl)
      `ALU_CTRL_AND:  ctrl_sub_less_sel = 1'b0;
      `ALU_CTRL_OR:   ctrl_sub_less_sel = 1'b0;
      `ALU_CTRL_XOR:  ctrl_sub_less_sel = 1'b0;
      `ALU_CTRL_ADD:  ctrl_sub_less_sel = 1'b0;
      `ALU_CTRL_SUB:  ctrl_sub_less_sel = 1'b1;
      `ALU_CTRL_SLT:  ctrl_sub_less_sel = 1'b1;
      `ALU_CTRL_SLTU: ctrl_sub_less_sel = 1'b1;
      `ALU_CTRL_SLL:  ctrl_sub_less_sel = 1'b0;
      `ALU_CTRL_SRL:  ctrl_sub_less_sel = 1'b0;
      `ALU_CTRL_SRA:  ctrl_sub_less_sel = 1'b0;
    endcase
  end


  always @(*) begin
    case (alu_ctrl)
      `ALU_CTRL_AND:  ctrl_slt_unsigned_sel = 1'b0;
      `ALU_CTRL_OR:   ctrl_slt_unsigned_sel = 1'b0;
      `ALU_CTRL_XOR:  ctrl_slt_unsigned_sel = 1'b0;
      `ALU_CTRL_ADD:  ctrl_slt_unsigned_sel = 1'b0;
      `ALU_CTRL_SUB:  ctrl_slt_unsigned_sel = 1'b0;
      `ALU_CTRL_SLT:  ctrl_slt_unsigned_sel = 1'b0;
      `ALU_CTRL_SLTU: ctrl_slt_unsigned_sel = 1'b1;
      `ALU_CTRL_SLL:  ctrl_slt_unsigned_sel = 1'b0;
      `ALU_CTRL_SRL:  ctrl_slt_unsigned_sel = 1'b0;
      `ALU_CTRL_SRA:  ctrl_slt_unsigned_sel = 1'b0;
    endcase
  end

  always @(*) begin
    case (alu_ctrl)
      `ALU_CTRL_AND:  ctrl_shift_sel = `ALU_SHIFT_NONE;
      `ALU_CTRL_OR:   ctrl_shift_sel = `ALU_SHIFT_NONE;
      `ALU_CTRL_XOR:  ctrl_shift_sel = `ALU_SHIFT_NONE;
      `ALU_CTRL_ADD:  ctrl_shift_sel = `ALU_SHIFT_NONE;
      `ALU_CTRL_SUB:  ctrl_shift_sel = `ALU_SHIFT_NONE;
      `ALU_CTRL_SLT:  ctrl_shift_sel = `ALU_SHIFT_NONE;
      `ALU_CTRL_SLTU: ctrl_shift_sel = `ALU_SHIFT_NONE;
      `ALU_CTRL_SLL:  ctrl_shift_sel = `ALU_SHIFT_SLL;
      `ALU_CTRL_SRL:  ctrl_shift_sel = `ALU_SHIFT_SRL;
      `ALU_CTRL_SRA:  ctrl_shift_sel = `ALU_SHIFT_SRA;
    endcase
  end

endmodule
