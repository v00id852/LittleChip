`include "Opcode.vh"

module BRANCH #(
  parameter DWIDTH = 32
) (
  input [DWIDTH - 1:0] rs1_in,
  input [DWIDTH - 1:0] rs2_in,
  input [2:0] func,
  output reg taken
);

  wire equal_res = (rs1_in == rs2_in);
  wire less_res = (rs1_in < rs2_in);

  wire equal_taken = func[0] == 1'b0 ? equal_res : !equal_res;
  wire unsigned_less_taken = func[0] == 1'b0 ? less_res : !less_res;
  wire signed_less_taken = (rs1_in[31] == rs2_in[31]) ? unsigned_less_taken : !unsigned_less_taken;

  always @(*) begin
    case (func[2:1])
      2'b00:  taken = equal_taken;
      2'b10:  taken = signed_less_taken;
      2'b11:  taken = unsigned_less_taken;
      default:   taken = 1'b0;
    endcase
  end

endmodule
