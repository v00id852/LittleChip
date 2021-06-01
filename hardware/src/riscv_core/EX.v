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
  input [DWIDTH - 1:0] forward_data_in,
  input [3:0] ctrl_alu_func,
  input [1:0] ctrl_alu_op,
  input [1:0] ctrl_alu_src_a,
  input [1:0] ctrl_alu_src_b,
  input ctrl_forward_a_sel,
  input ctrl_forward_b_sel,

  input ctrl_csr_we,
  input ctrl_csr_rd,
  input [11:0] csr_addr,
  input [2:0] csr_func,

  output [DWIDTH - 1:0] csr_data_out,
  output [DWIDTH - 1:0] csr_orig_data_out,  // the data written into csr
  output [DWIDTH - 1:0] alu_out
);

  reg [DWIDTH - 1:0] data_rs1_final, data_rs2_final;
  reg [DWIDTH - 1:0] alu_a_final, alu_b_final;

  always @(*) begin
    case (ctrl_alu_src_a)
      2'b00:   alu_a_final = data_rs1_final;
      2'b01:   alu_a_final = data_pc;  // For LUI/AUIPC inst
      2'b10:   alu_a_final = {DWIDTH{1'b0}};
      default: alu_a_final = data_rs1_final;
    endcase
  end

  always @(*) begin
    case (ctrl_alu_src_b)
      2'b00:   alu_b_final = data_rs2_final;
      2'b01:   alu_b_final = data_imm;
      2'b10:   alu_b_final = 32'd4;
      default: alu_b_final = data_rs2_final;
    endcase
  end

  always @(*) begin
    case (ctrl_forward_a_sel)
      1'b1: data_rs1_final = forward_data_in;
      default: data_rs1_final = data_rs1;
    endcase
  end

  always @(*) begin
    case (ctrl_forward_b_sel)
      1'b1: data_rs2_final = forward_data_in;
      default: data_rs2_final = data_rs2;
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
    .A  (alu_a_final),
    .B  (alu_b_final),
    .ctl(alu_ctrl_out),
    .out(alu_out)
  );

  reg [DWIDTH - 1:0] csr_data_in;

  always @(*) begin
    case (csr_func)
      `FNC_CSRRW: csr_data_in = data_rs1_final;
      `FNC_CSRRWI: csr_data_in = data_imm;
      default: csr_data_in = data_rs1_final;
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

  wire csr_orig_data_ce;
  wire [DWIDTH - 1:0] csr_orig_data_next, csr_orig_data_value;

  REGISTER_CE #(
    .N(DWIDTH),
    .INIT(0)
  ) csr_orig_data_reg (
    .clk(clk),
    .ce (csr_orig_data_ce),
    .d  (csr_orig_data_next),
    .q  (csr_orig_data_value)
  );

  assign csr_orig_data_ce   = ctrl_csr_we;
  assign csr_orig_data_next = csr_data_in;
  assign csr_orig_data_out  = csr_orig_data_value;

endmodule
