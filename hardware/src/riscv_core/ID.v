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
  input [4:0] addr_rd_ex_in,
  input [INST_WIDTH - 1:0] inst,
  input [DWIDTH - 1:0] data_rd,
  input [DWIDTH - 1:0] forward_data_in,
  input forward_a_sel_in,
  input forward_b_sel_in,

  output reg [  DWIDTH - 1:0] data_rs1,
  output reg [  DWIDTH - 1:0] data_rs2,
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
  output ctrl_pc_en,
  output ctrl_imem_en,

  output ctrl_zero_sel,

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

  wire ctrl_jump, ctrl_branch;
  wire ctrl_jalr_src;

  // Control Unit
  CONTROL #(
    .INST_WIDTH(INST_WIDTH)
  ) control (
    .inst(inst),
    .alu_op(ctrl_alu_op),
    .reg_write(ctrl_reg_we),
    .alu_src_a(ctrl_alu_src_a),
    .alu_src_b(ctrl_alu_src_b),
    .mem_write(ctrl_mem_write),
    .mem_read(ctrl_mem_read),
    .mem_to_reg(ctrl_mem_to_reg),
    .branch(ctrl_branch),
    .jump(ctrl_jump),
    .jalr_src(ctrl_jalr_src),
    .csr_we(ctrl_csr_we),
    .csr_rd(ctrl_csr_rd)
  );

  HAZARD_DETECTION hd (
    .clk(clk),
    .rst(rst),
    .opcode(inst[6:0]),
    .if_id_rs1(addr_rs1),
    .if_id_rs2(addr_rs2),
    .id_ex_rd(addr_rd_ex_in),
    .ctrl_pc_src(ctrl_pc_src),
    // output
    .ctrl_pc_en(ctrl_pc_en),
    .ctrl_imem_en(ctrl_imem_en),
    .ctrl_id_reg_flush(ctrl_id_reg_flush),
    .ctrl_zero_sel(ctrl_zero_sel)
  );

  wire branch_taken;
  wire [INST_WIDTH - 1:0] branch_pc_rs1;

  BRANCH branch (
    .rs1_in(data_rs1),
    .rs2_in(data_rs2),
    .func  (inst[14:12]),
    .taken (branch_taken)
  );

  assign ctrl_pc_src = ctrl_jump || (ctrl_branch && branch_taken);

  // pc_new = rs1/PC + immediate
  assign branch_pc_rs1 = ctrl_jalr_src ? data_rs1 : pc;
  assign branch_pc_new = branch_pc_rs1 + imm_gen_out;

  assign data_imm = imm_gen_out;
  assign data_pc = pc;

  assign csr_addr = inst[31:20];
  assign csr_func = inst[14:12];

endmodule

