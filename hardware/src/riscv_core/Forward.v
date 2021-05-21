`define FORWARD_EX  2'b01;
`define FORWARD_WB  2'b10;

module FORWARD #(
  parameter DWIDTH = 32
) (
  input [4:0] rs1_addr_id,
  input [4:0] rs2_addr_id,
  input [4:0] rd_addr_id,
  input [4:0] ctrl_reg_we,
  output [1:0] forward_a_sel,
  output [1:0] forward_b_sel
);

  // EX Hazard
  always @(*) begin
    if (ctrl_reg_we && rs1_id_addr == rd_ex_addr && rd_ex_addr != 5'd0) begin
      forward_a_sel = 2'b01;
    end else begin
      forward_a_sel = 2'b00;
    end
  end

  always @(*) begin
    if (ctrl_reg_we && rs2_addr_id == rd_addr_ex && rd_addr_ex != 5'd0) begin
      forward_b_sel = 2'b01;
    end else begin
      forward_b_sel = 2'b00;
    end
  end

endmodule