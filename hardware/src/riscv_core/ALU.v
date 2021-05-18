// Module: ALU
// Disc: ALU supports AND,OR,Add,Subtract operations
module ALU #(
  parameter DWIDTH = 32
) (
  input [DWIDTH - 1:0] A, B,
  input [3:0] ctl,
  output [DWIDTH - 1:0] out,
  output zero
);

  reg [DWIDTH - 1:0] out;
  
  assign zero = (out == 0);

  always @(*) begin
    case (ctl)
      0: out = A & B;
      1: out = A | B;
      2: out = A + B;
      6: out = A - B;
      7: out = A < B ? 1 : 0;
      12: out = ~(A | B);
      default: out = 0;
    endcase
  end

endmodule

module ALUCtrl (
  input [3:0] func,
  input [1:0] alu_op,
  output [3:0] alu_ctrl
);

  assign alu_ctrl[0] = alu_op[1] & (func[3] | func[0]);
  assign alu_ctrl[1] = !alu_op[1] | !func[2];
  assign alu_ctrl[2] = alu_op[0] | (alu_op[1] & func[1]);
  assign alu_ctrl[3] = 0;

endmodule