module ID #(
  parameter INST_WIDTH = 32,
  parameter DWIDTH = 32,
  parameter PC_WIDTH = 32
) (
  input clk,
  input rst,

  input [PC_WIDTH - 1:0] pc,

  input reg_we,
  input [INST_WIDTH - 1:0] inst,
  input [DWIDTH - 1:0] data_rd,
  output [DWIDTH - 1:0] data_rs1, data_rs2,

  output [PC_WIDTH - 1:0] branch_pc_new,
  output [DWIDTH - 1:0] imm,
  output ctrl_pc_src,
  output ctrl_reg_we,
  output ctrl_alu_src,
  output ctrl_mem_write,
  output ctrl_mem_read,
  output ctrl_mem_to_reg
);

  wire rf_we;
  wire [4:0] rf_ra1, rf_ra2, rf_wa;
  wire [31:0] rf_wd;
  wire [31:0] rf_rd1, rf_rd2;

  // Asynchronous read: read data is available in the same cycle
  // Synchronous write: write takes one cycle
  ASYNC_RAM_1W2R #(
    .PC_WIDTH(5),
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

  // register 1
  assign rf_ra1 = inst[19:15];
  // register 2
  assign rf_ra2 = inst[24:20];
  // register rd
  assign rf_wa  = inst[11:7];
  // register files write enable
  assign rf_we  = reg_we;
  assign rf_wd = data_rd;

  assign data_rs1 = rf_rd1;
  assign data_rs2 = rf_rd2;

  IMM_GEN #(
    .INST_WIDTH(INST_WIDTH),
    .DWIDTH(DWIDTH)
  ) imm_gen (
    .inst_in(inst),
    .imm_out(imm)
  );

  // Control Unit
  CONTROL control(
    .opcode(inst[6:0]),
    .reg_write(ctrl_reg_we),
    .alu_src(ctrl_alu_src),
    .mem_write(ctrl_mem_write),
    .mem_read(ctrl_mem_read),
    .mem_to_reg(ctrl_mem_to_reg),
    .pc_src(ctrl_pc_src)
  );
  
  // PC + immediate
  assign branch_pc_new = pc + imm;
   
endmodule

