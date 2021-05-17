
module Riscv151 #(
  parameter CPU_CLOCK_FREQ = 50_000_000,
  parameter RESET_PC       = 32'h4000_0000,
  parameter BAUD_RATE      = 115200,
  parameter BIOS_MIF_HEX   = "bios151v3.mif"
) (
  input clk,
  input rst,
  input FPGA_SERIAL_RX,
  output FPGA_SERIAL_TX,
  output [31:0] csr
);
  // Memories
  localparam BIOS_AWIDTH = 11;
  localparam BIOS_DWIDTH = 32;

  wire [BIOS_AWIDTH-1:0] bios_addra, bios_addrb;
  wire [BIOS_DWIDTH-1:0] bios_douta, bios_doutb;

  // BIOS Memory
  // Synchronous read: read takes one cycle
  // Synchronous write: write takes one cycle
  SYNC_ROM_DP #(
    .AWIDTH (BIOS_AWIDTH),
    .DWIDTH (BIOS_DWIDTH),
    .MIF_HEX(BIOS_MIF_HEX)
  ) bios_mem (
    .q0(bios_douta),  // output
    .addr0(bios_addra),  // input
    .en0(1'b1),

    .q1(bios_doutb),  // output
    .addr1(bios_addrb),  // input
    .en1(1'b1),

    .clk(clk)
  );

  localparam DMEM_AWIDTH = 14;
  localparam DMEM_DWIDTH = 32;

  wire [DMEM_AWIDTH-1:0] dmem_addra;
  wire [DMEM_DWIDTH-1:0] dmem_dina, dmem_douta;
  wire [3:0] dmem_wea;

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
    .en(1'b1),
    .clk(clk)
  );




  // UART Receiver
  wire [7:0] uart_rx_data_out;
  wire uart_rx_data_out_valid;
  wire uart_rx_data_out_ready;

  uart_receiver #(
    .CLOCK_FREQ(CPU_CLOCK_FREQ),
    .BAUD_RATE (BAUD_RATE)
  ) uart_rx (
    .clk           (clk),
    .rst           (rst),
    .data_out      (uart_rx_data_out),  // output
    .data_out_valid(uart_rx_data_out_valid),  // output
    .data_out_ready(uart_rx_data_out_ready),  // input
    .serial_in     (FPGA_SERIAL_RX)  // input
  );

  // UART Transmitter
  wire [7:0] uart_tx_data_in;
  wire uart_tx_data_in_valid;
  wire uart_tx_data_in_ready;

  uart_transmitter #(
    .CLOCK_FREQ(CPU_CLOCK_FREQ),
    .BAUD_RATE (BAUD_RATE)
  ) uart_tx (
    .clk          (clk),
    .rst          (rst),
    .data_in      (uart_tx_data_in),  // input
    .data_in_valid(uart_tx_data_in_valid),  // input
    .data_in_ready(uart_tx_data_in_ready),  // output
    .serial_out   (FPGA_SERIAL_TX)  // output
  );

  // TODO: Your code to implement a fully functioning RISC-V core
  // Add as many modules as you want
  // Feel free to move the memory modules around
  localparam PC_WIDTH = 32;
  localparam INST_WIDTH = 32;

  wire ctrl_pc_src;
  wire [PC_WIDTH - 1:0] pc_new_val, pc_if_out;

  // IF part, fetch instruction from BIOS or IMEM

  PC #(
    .PC_WIDTH(PC_WIDTH),
    .RESET_PC_VAL(RESET_PC)
  ) pc (
    .clk(clk),
    .rst(rst),
    .pc_sel_in(ctrl_pc_src),
    .pc_new_in(pc_new_val),
    .pc_out(pc_if_out)
  );

  localparam IMEM_AWIDTH = 14;
  localparam IMEM_DWIDTH = 32;

  wire [IMEM_AWIDTH-1:0] imem_addra, imem_addrb;
  wire [IMEM_DWIDTH-1:0] imem_douta, imem_doutb;
  wire [IMEM_DWIDTH-1:0] imem_dina, imem_dinb;
  wire [3:0] imem_wea, imem_web;

  wire [INST_WIDTH - 1:0] inst_if_out;

  // Instruction Memory
  // Synchronous read: read takes one cycle
  // Synchronous write: write takes one cycle
  // Write-byte-enable: select which of the four bytes to write
  SYNC_RAM_DP_WBE #(
    .AWIDTH(IMEM_AWIDTH),
    .DWIDTH(IMEM_DWIDTH)
  ) imem (
    .q0(imem_douta),    // output
    .d0(imem_dina),     // input
    .addr0(imem_addra), // input
    .wbe0(imem_wea),    // input
    .en0(1'b1),

    .q1(imem_doutb),    // output
    .d1(imem_dinb),     // input
    .addr1(imem_addrb), // input
    .wbe1(imem_web),    // input
    .en1(1'b1),

    .clk(clk)
  );

  assign bios_addra  = pc_if_out[11:0];
  assign imem_addrb  = pc_if_out[13:0];
  assign inst_if_out = pc_if_out[30] == 1'b1 ? bios_douta : imem_doutb;

  // IF/ID Registers
  wire [  PC_WIDTH - 1:0] pc_id_in;
  wire [INST_WIDTH - 1:0] inst_id_in;

  assign inst_id_in = inst_if_out;

  REGISTER_R #(
    .N(PC_WIDTH),
    .INIT(0)
  ) if_id_pc (
    .d  (pc_if_out),
    .q  (pc_id_in),
    .clk(clk),
    .rst(rst)
  );

  wire [DMEM_DWIDTH - 1:0] rs1_id_out, rs2_id_out;
  wire [PC_WIDTH - 1:0] pc_branch_id_out;
  wire ctrl_pc_src_id_out, ctrl_reg_we_id_out;
  wire ctrl_mem_write_id_out;
  wire ctrl_mem_read_id_out, ctrl_mem_to_reg_id_out;
  wire [1:0] ctrl_alu_op_id_out, ctrl_alu_src_id_out;

  wire ctrl_reg_we_id_in;
  wire [DMEM_DWIDTH - 1:0] rd_id_in;
  wire [4:0] addr_rs1_id_in, addr_rs2_id_in, addr_rd_id_in;

  ID #(
    .PC_WIDTH(PC_WIDTH),
    .INST_WDITH(INST_WIDTH),
    .DWIDTH(DMEM_DWIDTH),
  ) id (
    .clk(clk),
    .rst(rst),
    // input
    .pc(pc_id_in),
    .addr_rs1(addr_rs1_id_in),
    .addr_rs2(addr_rs2_id_in),
    .addr_rd(addr_rd_id_in),
    .inst(inst_id_in),
    .reg_we(ctrl_reg_we_id_in),
    .data_rd(rd_id_in),
    // output
    .data_rs1(rs1_id_out),
    .data_rs2(rs2_id_out),
    .ctrl_alu_op(ctrl_alu_op_id_out),
    .ctrl_pc_src(ctrl_pc_src_id_out),
    .ctrl_reg_we(ctrl_reg_we_id_out),
    .ctrl_alu_src(ctrl_alu_src_id_out),
    .ctrl_mem_write(ctrl_mem_write_id_out),
    .ctrl_mem_read(ctrl_mem_read_id_out),
    .ctrl_mem_to_reg(ctrl_mem_to_reg_id_out)
  );

  assign addr_rs1_id_in = inst_id_in[19:15];
  assign addr_rs2_id_in = inst_id_in[24:20];

  // ID-EX pipeline

  wire [INST_WIDTH - 1:0] inst_ex_in;
  wire [DMEM_DWIDTH - 1:0] rs1_ex_in, rs2_ex_in;
  wire [DMEM_DWIDTH - 1:0] imm_ex_in;

  wire ctrl_pc_src_ex_in, ctrl_reg_we_ex_in;
  wire ctrl_alu_src_ex_in, ctrl_mem_we_ex_in;
  wire ctrl_mem_rd_ex_in, ctrl_mem_to_reg_ex_in;
  wire [1:0] ctrl_alu_op_ex_in;

  REGISTER #(
    .N(2)
  ) id_ex_ctrl_alu_src (
    .clk(clk),
    .d  (ctrl_alu_src_id_out),
    .q  (ctrl_alu_src_ex_in)
  );

  REGISTER #(
    .N(1)
  ) id_ex_ctrl_pc_src (
    .clk(clk),
    .d  (ctrl_pc_src_id_out),
    .q  (ctrl_pc_src_ex_in)
  );

  REGISTER #(
    .N(1)
  ) id_ex_ctrl_reg_we (
    .clk(clk),
    .d  (ctrl_reg_we_id_out),
    .q  (ctrl_reg_we_ex_in)
  );

  REGISTER #(
    .N(1)
  ) id_ex_ctrl_mem_write (
    .clk(clk),
    .d  (ctrl_mem_write_id_out),
    .q  (ctrl_mem_we_ex_in)
  );

  REGISTER #(
    .N(1)
  ) id_ex_ctrl_mem_read (
    .clk(clk),
    .d  (ctrl_mem_read_id_out),
    .q  (ctrl_mem_rd_ex_in)
  );

  REGISTER #(
    .N(1)
  ) id_ex_ctrl_mem_to_reg (
    .clk(clk),
    .d  (ctrl_mem_to_reg_id_out),
    .q  (ctrl_mem_to_reg_ex_in)
  );

  REGISTER #(
    .N(2)
  ) id_ex_ctrl_alu_op (
    .clk(clk),
    .d  (ctrl_alu_op_id_out),
    .q  (ctrl_alu_op_ex_in)
  );

  REGISTER_R #(
    .N(DMEM_DWIDTH)
  ) id_ex_rs1 (
    .clk(clk),
    .rst(rst),
    .d  (rs1_id_out),
    .q  (rs1_ex_in)
  );

  REGISTER_R #(
    .N(DMEM_DWIDTH)
  ) id_ex_rs2 (
    .clk(clk),
    .rst(rst),
    .d  (rs2_id_out),
    .q  (rs2_ex_in)
  );

  REGISTER_R #(
    .N(DMEM_DWIDTH)
  ) id_ex_imm (
    .clk(clk),
    .rst(rst),
    .d  (imm_id_out),
    .q  (imm_ex_in)
  );

  REGISTER_R #(
    .N(INST_WIDTH)
  ) id_ex_inst (
    .clk(clk),
    .rst(rst),
    .d  (inst_id_in),
    .q  (inst_ex_in)
  );


  wire [3:0] alu_func, addr_rd_ex_in;
  wire [DMEM_DWIDTH - 1:0] rd_ex_out;

  assign alu_func = {inst_ex_in[30], inst_ex_in[14:12]};
  assign addr_rd_ex_in = inst_ex_in[11:7];

  // Part of ID pipeline, buffer reg_we and addr_rd from EX
  REGISTER #(
    .N(1)
  ) ex_id_reg_we (
    .clk(clk),
    .d  (ctrl_reg_we_ex_in),
    .q  (ctrl_reg_we_id_in)
  );

  REGISTER #(
    .N(5)
  ) ex_id_addr_rd (
    .clk(clk),
    .d  (addr_rd_ex_in),
    .q  (addr_rd_id_in)
  );

  EX #(
    .DWIDTH(DMEM_DWIDTH)
  ) ex (
    .clk(clk),
    .data_rs1(rs1_ex_in),
    .data_rs2(rs2_ex_in),
    .data_imm(imm_ex_in),
    .ctrl_alu_func(alu_func),
    .ctrl_alu_op(ctrl_alu_op_ex_in),
    .ctrl_alu_src_a(2'b00),  // FIXME
    .ctrl_alu_src_b(ctrl_alu_src_ex_in),  // FIXME
    .ctrl_mem_we(ctrl_mem_we_ex_in),
    .ctrl_mem_rd(ctrl_mem_rd_ex_in),
    .ctrl_mem_to_reg(ctrl_mem_to_reg_ex_in),
    .data_out(rd_ex_out)
  );

  assign rd_id_in = rd_ex_out;


endmodule
