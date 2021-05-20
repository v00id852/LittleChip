module ID #(
  parameter INST_WIDTH = 32,
  parameter DWIDTH = 32,
  parameter PC_WIDTH = 32
) (
  input clk,
  input rst,

  input [PC_WIDTH - 1:0] pc,

  input reg_we,
  input [4:0] addr_rs1, addr_rs2, addr_rd,
  input [INST_WIDTH - 1:0] inst,
  input [DWIDTH - 1:0] data_rd,
  output [DWIDTH - 1:0] data_rs1, data_rs2,
  output [DWIDTH - 1:0] data_utype_rs1,
  output [DWIDTH - 1:0] data_imm,

  output [PC_WIDTH - 1:0] branch_pc_new,
  output [1:0] ctrl_alu_op,
  output ctrl_pc_src,
  output ctrl_reg_we,
  output [1:0] ctrl_alu_src_a,
  output [1:0] ctrl_alu_src_b,
  output ctrl_mem_write,
  output ctrl_mem_read,
  output ctrl_mem_to_reg,
  output ctrl_id_reg_flush
);

  wire rf_we;
  wire [4:0] rf_ra1, rf_ra2, rf_wa;
  wire [31:0] rf_wd;
  wire [31:0] rf_rd1, rf_rd2;
  wire [31:0] imm_gen_out;

  // Asynchronous read: read data is available in the same cycle
  // Synchronous write: write takes one cycle
  ASYNC_RAM_1W2R #(
    .AWIDTH(5),
    .DWIDTH(32)
  ) rf (
    .d0(rf_wd),     // input
    .addr0(rf_wa),  // input
    .we0(rf_we),    // input

    .q1(rf_rd1),  // output
    .addr1(rf_ra1),  // input

    .q2(rf_rd2),  // output
    .addr2(rf_ra2),  // input

    .clk(clk)
  );

  assign rf_wa = addr_rd;
  assign rf_ra1 = addr_rs1;
  assign rf_ra2 = addr_rs2;
  // // register 1
  // assign rf_ra1 = inst[19:15];
  // // register 2
  // assign rf_ra2 = inst[24:20];
  // // register rd
  // assign rf_wa  = inst[11:7];
  // register files write enable
  assign rf_we  = reg_we;
  assign rf_wd = data_rd;

  assign data_rs1 = rf_rd1;
  assign data_rs2 = rf_rd2;

  IMM_GEN #(
    .IWIDTH(INST_WIDTH),
    .DWIDTH(DWIDTH)
  ) imm_gen (
    .inst_in(inst),
    .imm_out(imm_gen_out)
  );

  wire ctrl_utype_src, ctrl_jtype_src;

  wire [1:0] ctrl_alu_op_inner;
  wire ctrl_reg_we_inner;
  wire [1:0] ctrl_alu_src_a_inner, ctrl_alu_src_b_inner;
  wire ctrl_mem_write_inner, ctrl_mem_read_inner, ctrl_mem_to_reg_inner;

  // Control Unit
  CONTROL control(
    .opcode(inst[6:0]),
    .alu_op(ctrl_alu_op_inner),
    .reg_write(ctrl_reg_we_inner),
    .alu_src_a(ctrl_alu_src_a_inner),
    .alu_src_b(ctrl_alu_src_b_inner),
    .mem_write(ctrl_mem_write_inner),
    .mem_read(ctrl_mem_read_inner),
    .mem_to_reg(ctrl_mem_to_reg_inner),
    .pc_src(ctrl_pc_src),
    .utype_src(ctrl_utype_src),
    .jtype_src(ctrl_jtype_src)
  );

  wire ctrl_zero_sel;

  HAZARD_DETECTION hd (
    .clk(clk),
    .opcode(inst[6:0]),
    .ctrl_id_reg_flush(ctrl_id_reg_flush),
    .ctrl_zero_sel(ctrl_zero_sel)
  );

  // Avoid data hazard and control hazard
  assign ctrl_alu_op = ctrl_zero_sel ? 2'b00 : ctrl_alu_op_inner;
  assign ctrl_reg_we = ctrl_zero_sel ? 1'b0 : ctrl_reg_we_inner;
  assign ctrl_alu_src_a = ctrl_zero_sel ? 2'b00 : ctrl_alu_src_a_inner;
  assign ctrl_alu_src_b = ctrl_zero_sel ? 2'b00 : ctrl_alu_src_b_inner;
  assign ctrl_mem_write = ctrl_zero_sel ? 1'b0 : ctrl_mem_write_inner;
  assign ctrl_mem_read = ctrl_zero_sel ? 1'b0 : ctrl_mem_read_inner;
  assign ctrl_mem_to_reg = ctrl_zero_sel ? 1'b0 : ctrl_mem_to_reg_inner;
  
  // PC + immediate
  assign branch_pc_new = pc + imm_gen_out;
  assign data_utype_rs1 = ctrl_utype_src ? pc : {DWIDTH{1'b0}}; 
  assign data_imm = ctrl_jtype_src ? {{(DWIDTH - 3){1'b0}}, 3'd4} : imm_gen_out;
   
endmodule

