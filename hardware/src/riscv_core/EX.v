`include "Opcode.vh"

module EX #(
  parameter DWIDTH = 32,
  parameter INST_WIDTH = 32
) (
  input clk,
  input [DWIDTH - 1:0] data_rs1,
  input [DWIDTH - 1:0] data_rs2,
  input [INST_WIDTH - 1:0] data_pc,
  input [DWIDTH - 1:0] data_imm,
  input [DWIDTH - 1:0] forward_alu_out,
  input [3:0] ctrl_alu_func,
  input [1:0] ctrl_alu_op,
  input [1:0] ctrl_alu_src_a,
  input [1:0] ctrl_alu_src_b,
  input [1:0] ctrl_forward_a_sel,
  input [1:0] ctrl_forward_b_sel,

  input ctrl_csr_we,
  input ctrl_csr_rd,
  input [11:0] csr_addr,
  input [2:0] csr_func,

  output [DWIDTH - 1:0] csr_data_out,
  output [DWIDTH - 1:0] alu_out
);

  reg [DWIDTH - 1:0] data_alu_a, data_alu_b;
  reg [DWIDTH - 1:0] alu_a, alu_b;

  always @(*) begin
    case (ctrl_alu_src_a)
      2'b00:   data_alu_a = data_rs1;
      2'b01:   data_alu_a = data_pc;  // For LUI/AUIPC inst
      2'b10:   data_alu_a = {DWIDTH{1'b0}};
      default: data_alu_a = data_rs1;
    endcase
  end

  always @(*) begin
    case (ctrl_alu_src_b)
      2'b00:   data_alu_b = data_rs2;
      2'b01:   data_alu_b = data_imm;
      2'b10:   data_alu_b = 32'd4;
      default: data_alu_b = data_rs2;
    endcase
  end

  always @(*) begin
    case (ctrl_forward_a_sel)
      2'b01: alu_a = forward_alu_out;
      default: alu_a = data_alu_a;
    endcase
  end

  always @(*) begin
    case (ctrl_forward_b_sel)
      2'b01: alu_b = forward_alu_out;
      default: alu_b = data_alu_b;
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
    .rd(ctrl_csr_rd),
    .addr(csr_addr),
    .func(csr_func),
    .data_in(csr_data_in),
    .data_out(csr_data_out)
  );

endmodule
