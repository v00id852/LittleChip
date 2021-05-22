module ID #(
  parameter INST_WIDTH = 32,
  parameter DWIDTH = 32,
  parameter PC_WIDTH = 32
) (
  input clk,
  input rst,
  input [PC_WIDTH - 1:0] pc,
  input reg_we,

  input [4:0] addr_rs1,
  input [4:0] addr_rs2,
  input [4:0] addr_rd,
  input [INST_WIDTH - 1:0] inst,
  input [DWIDTH - 1:0] data_rd,
  input [DWIDTH - 1:0] forward_data_in,
  input forward_a_sel_in,
  input forward_b_sel_in,

  output [  DWIDTH - 1:0] data_rs1,
  output [  DWIDTH - 1:0] data_rs2,
  output [PC_WIDTH - 1:0] data_pc,
  output [  DWIDTH - 1:0] data_imm,

  output [PC_WIDTH - 1:0] branch_pc_new,
  output [1:0] ctrl_alu_op,
  output ctrl_pc_src,
  output ctrl_reg_we,
  output [1:0] ctrl_alu_src_a,
  output [1:0] ctrl_alu_src_b,
  output ctrl_mem_write,
  output ctrl_mem_read,
  output [1:0] ctrl_mem_to_reg,
  output ctrl_id_reg_flush,

  output ctrl_csr_we,
  output ctrl_csr_rd,
  output [11:0] csr_addr,
  output [2:0] csr_func
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

  assign rf_wa  = addr_rd;
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
  assign rf_wd  = data_rd;

  reg [DWIDTH - 1:0] data_rs1, data_rs2;

  always @(*) begin
    case (forward_a_sel_in)
      1'b1: data_rs1 = forward_data_in;
      default: data_rs1 = rf_rd1;
    endcase
  end

  always @(*) begin
    case (forward_b_sel_in)
      1'b1: data_rs2 = forward_data_in;
      default: data_rs2 = rf_rd2;
    endcase
  end

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
  wire [1:0] ctrl_mem_to_reg_inner;
  wire ctrl_mem_write_inner, ctrl_mem_read_inner;
  wire ctrl_csr_we_inner;
  wire ctrl_csr_rd_inner;
  wire ctrl_jump, ctrl_branch;
  wire ctrl_jalr_src;

  // Control Unit
  CONTROL #(
    .INST_WIDTH(INST_WIDTH)
  ) control (
    .inst(inst),
    .alu_op(ctrl_alu_op_inner),
    .reg_write(ctrl_reg_we_inner),
    .alu_src_a(ctrl_alu_src_a_inner),
    .alu_src_b(ctrl_alu_src_b_inner),
    .mem_write(ctrl_mem_write_inner),
    .mem_read(ctrl_mem_read_inner),
    .mem_to_reg(ctrl_mem_to_reg_inner),
    .branch(ctrl_branch),
    .jump(ctrl_jump),
    .jalr_src(ctrl_jalr_src),
    .csr_we(ctrl_csr_we_inner),
    .csr_rd(ctrl_csr_rd_inner)
  );

  wire ctrl_zero_sel;

  HAZARD_DETECTION hd (
    .clk(clk),
    .opcode(inst[6:0]),
    .ctrl_pc_src(ctrl_pc_src),
    .ctrl_id_reg_flush(ctrl_id_reg_flush),
    .ctrl_zero_sel(ctrl_zero_sel)
  );

  wire branch_taken;
  wire [INST_WIDTH - 1:0] branch_pc_rs1;

  BRANCH branch (
    .rs1_in(rf_rd1),
    .rs2_in(rf_rd2),
    .func  (inst[14:12]),
    .taken (branch_taken)
  );

  assign ctrl_pc_src = ctrl_jump || (ctrl_branch && branch_taken);

  // FIXME: ctrl_zero_sel as pipeline rst
  // zero ex stage signals to avoid data hazard and control hazard
  assign ctrl_alu_op = ctrl_zero_sel ? 2'b00 : ctrl_alu_op_inner;
  assign ctrl_reg_we = ctrl_zero_sel ? 1'b0 : ctrl_reg_we_inner;
  assign ctrl_alu_src_a = ctrl_zero_sel ? 2'b00 : ctrl_alu_src_a_inner;
  assign ctrl_alu_src_b = ctrl_zero_sel ? 2'b00 : ctrl_alu_src_b_inner;
  assign ctrl_mem_write = ctrl_zero_sel ? 1'b0 : ctrl_mem_write_inner;
  assign ctrl_mem_read = ctrl_zero_sel ? 1'b0 : ctrl_mem_read_inner;
  assign ctrl_mem_to_reg = ctrl_zero_sel ? 2'b00 : ctrl_mem_to_reg_inner;
  assign ctrl_csr_we = ctrl_zero_sel ? 1'b0 : ctrl_csr_we_inner;
  assign ctrl_csr_rd = ctrl_zero_sel ? 1'b0 : ctrl_csr_rd_inner;

  // pc_new = rs1/PC + immediate
  assign branch_pc_rs1 = ctrl_jalr_src ? data_rs1 : pc;
  assign branch_pc_new = branch_pc_rs1 + imm_gen_out;

  assign data_imm = imm_gen_out;
  assign data_pc = pc;

  assign csr_addr = inst[31:20];
  assign csr_func = inst[14:12];

endmodule

