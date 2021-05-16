module EX #(
  parameter DWIDTH = 32
) (
  input clk,
  input [DWIDTH - 1:0] data_rs1, data_rs2,
  input [DWIDTH - 1:0] data_imm,
  input [3:0] data_func,
  input [1:0] ctrl_alu_op,
  input ctrl_alu_src_a, ctrl_alu_src_b,
  input ctrl_mem_we, ctrl_mem_rd,
  input ctrl_mem_to_reg,
  
  output [DWIDTH - 1:0] data_out
);

  wire [DWIDTH - 1:0] alu_a, alu_b;
  
  // always @(*) begin
  //   case (ctrl_alu_src_a) 
  //   endcase
  // end

  // always @(*) begin
  //   case (ctrl_alu_src_b)
  //   endcase 
  // end

  wire [DWIDTH - 1:0] alu_out;
  wire [3:0] alu_ctrl_out;
  ALUCtrl alu_ctrl(
    .func(data_func),
    .alu_op(ctrl_alu_op),
    .alu_ctrl(alu_ctrl_out)
  );

  ALU #(.DWIDTH(DWIDTH)) alu (
    .A(data_alu_a), 
    .B(data_alu_b),
    .ctl(alu_ctrl_out), 
    .out(alu_out),
    .zero(alu_zero)
  );

  localparam DMEM_AWIDTH = 14;
  localparam DMEM_DWIDTH = DWIDTH;

  wire [DMEM_AWIDTH-1:0] dmem_addra;
  wire [DMEM_DWIDTH-1:0] dmem_dina, dmem_douta;
  wire [3:0] dmem_wea;
  wire dmem_en;

  // Data Memory
  // Synchronous read: read takes one cycle
  // Synchronous write: write takes one cycle
  // Write-byte-enaBLe: select which of the four bytes to write
  SYNC_RAM_WBE #(
    .AWIDTH(DMEM_AWIDTH),
    .DWIDTH(DMEM_DWIDTH)
  ) dmem (
    .q(dmem_douta),    // output
    .d(dmem_dina),     // input
    .addr(dmem_addra), // input
    .wbe(dmem_wea),    // input
    .en(dmem_en),
    .clk(clk)
  );

  // FIXME: lh/lb

  assign dmem_dina = data_rs2;
  assign dmem_addra = alu_out[15: 2];
  assign dmem_en = ctrl_mem_we;
  assign dmem_wea = 4'b1 << alu_addra[1:0];

  always @(*) begin
    if (ctrl_mem_to_reg == 1'b1)
      data_out = dmem_douta;
    else
      data_out = alu_out;
  end

endmodule