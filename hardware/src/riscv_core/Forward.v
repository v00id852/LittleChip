`define FORWARD_EX 2'b01;
`define FORWARD_WB 2'b10;

module FORWARD #(
  parameter DWIDTH = 32
) (
  input [4:0] rs1_addr_id,
  input [4:0] rs2_addr_id,
  input [6:0] opcode_id,
  input [4:0] rd_addr_ex_in,
  input [4:0] rd_addr_id_in,
  input ctrl_reg_we_ex_in,
  input ctrl_reg_we_id_in,
  output ex_forward_a_sel,
  output ex_forward_b_sel,
  output ex_forward_data_sel,
  output id_forward_a_sel,
  output id_forward_b_sel
);

  reg ex_forward_a_sel, ex_forward_b_sel;
  reg ex_forward_data_sel;
  reg id_forward_a_sel, id_forward_b_sel;

  // EX Hazard
  always @(*) begin
    if (ctrl_reg_we_ex_in && rs1_addr_id == rd_addr_ex_in && rd_addr_ex_in != 5'd0) begin
      ex_forward_a_sel = 1'b1;
    end else begin
      ex_forward_a_sel = 1'b0;
    end
  end

  always @(*) begin
    if (ctrl_reg_we_ex_in && rs2_addr_id == rd_addr_ex_in && rd_addr_ex_in != 5'd0) begin
      if (opcode_id == `OPC_STORE)
        // if the rd in the previous instruction is the one of the source registers in the next instruction,
        // but the opcode is store, the alu data should not be forwarded
        ex_forward_b_sel = 1'b0;
      else
        ex_forward_b_sel = 1'b1;
    end else begin
      ex_forward_b_sel = 1'b0;
    end
  end

  always @(*) begin
    if (ctrl_reg_we_ex_in && rs2_addr_id == rd_addr_ex_in && opcode_id == `OPC_STORE) begin
      ex_forward_data_sel = 1'b1;
    end else begin
      ex_forward_data_sel = 1'b0;
    end
  end

  always @(*) begin
    if (ctrl_reg_we_id_in && rs1_addr_id == rd_addr_id_in && rd_addr_id_in != 5'd0) begin
      id_forward_a_sel = 1'b1;
    end else begin
      id_forward_a_sel = 1'b0;
    end
  end

  always @(*) begin
    if (ctrl_reg_we_id_in && rs2_addr_id == rd_addr_id_in && rd_addr_id_in != 5'd0) begin
      id_forward_b_sel = 1'b1;
    end else begin
      id_forward_b_sel = 1'b0;
    end
  end
endmodule
