`include "Opcode.vh"

module BRANCH #(
  parameter DWIDTH = 32
) (
  input [DWIDTH - 1:0] rs1_in,
  input [DWIDTH - 1:0] rs2_in,
  input [2:0] func,
  output reg taken
);

  always @(*) begin
    case (func)
      `FNC_BEQ:  taken = rs1_in == rs2_in;
      `FNC_BNE:  taken = !(rs1_in == rs2_in);
      `FNC_BLT:  taken = $signed(rs1_in) < $signed(rs2_in);
      `FNC_BGE:  taken = !($signed(rs1_in) < $signed(rs2_in));
      `FNC_BLTU: taken = rs1_in < rs2_in;
      `FNC_BGEU: taken = !(rs1_in < rs2_in);
      default:   taken = 1'b0;
    endcase
  end

endmodule
