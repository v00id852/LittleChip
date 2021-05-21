`include "Opcode.vh"

module EX #(
  parameter DWIDTH = 32
) (
  input clk,
  input [DWIDTH - 1:0] data_rs1,
  input [DWIDTH - 1:0] data_rs2,
  input [DWIDTH - 1:0] data_imm,
  input [DWIDTH - 1:0] data_utype_rs1,
  input [3:0] ctrl_alu_func,
  input [1:0] ctrl_alu_op,
  input [1:0] ctrl_alu_src_a,
  input [1:0] ctrl_alu_src_b,

  input ctrl_csr_we,
  input [11:0] csr_addr,
  input [2:0] csr_func,

  output [DWIDTH - 1:0] csr_data_out,
  output [DWIDTH - 1:0] alu_out
);

  reg [DWIDTH - 1:0] alu_a, alu_b;

  always @(*) begin
    case (ctrl_alu_src_a)
      2'b00:   alu_a = data_rs1;
      2'b01:   alu_a = data_utype_rs1;  // For LUI/AUIPC inst
      // TODO: add forwarding signals
      default: alu_a = data_rs1;
    endcase
  end

  always @(*) begin
    case (ctrl_alu_src_b)
      2'b00:   alu_b = data_rs2;
      2'b01:   alu_b = data_imm;
      // TODO: add forwarding signals
      default: alu_b = data_rs2;
    endcase
  end

  wire [DWIDTH - 1:0] alu_out;
  wire [3:0] alu_ctrl_out;
  ALUCtrl alu_ctrl (
    .func(ctrl_alu_func),
    .alu_op(ctrl_alu_op),
    .alu_ctrl(alu_ctrl_out)
  );

  ALU #(
    .DWIDTH(DWIDTH)
  ) alu (
    .A  (alu_a),
    .B  (alu_b),
    .ctl(alu_ctrl_out),
    .out(alu_out)
  );

  reg [DWIDTH - 1:0] csr_data_in;

  always @(*) begin
    case (csr_func)
      `FNC_CSRRW: csr_data_in = data_rs1;
      `FNC_CSRRWI: csr_data_in = data_imm;
      default: csr_data_in = data_rs1;
    endcase
  end

  CSR #(
    .DWIDTH(DWIDTH)
  ) csr (
    .clk(clk),
    .we(ctrl_csr_we),
    .addr(csr_addr),
    .data_in(csr_data_in),
    .data_out(csr_data_out)
  );

endmodule
