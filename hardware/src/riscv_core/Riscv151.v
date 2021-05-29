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
  wire bios_ena;

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
    .en0(bios_ena),

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
  wire [PC_WIDTH - 1:0] pc_new_if_in, pc_if_out;
  wire pc_en;

  // IF part, fetch instruction from BIOS or IMEM

  PC #(
    .PC_WIDTH(PC_WIDTH),
    .RESET_PC_VAL(RESET_PC)
  ) pc (
    .clk(clk),
    .rst(rst),
    .pc_sel_in(ctrl_pc_src),
    .pc_en(pc_en),
    .pc_new_in(pc_new_if_in),
    .pc_out(pc_if_out)
  );

  localparam IMEM_AWIDTH = 14;
  localparam IMEM_DWIDTH = 32;

  wire [IMEM_AWIDTH-1:0] imem_addra, imem_addrb;
  wire [IMEM_DWIDTH-1:0] imem_douta, imem_doutb;
  wire [IMEM_DWIDTH-1:0] imem_dina, imem_dinb;
  wire [3:0] imem_wea, imem_web;
  wire imem_enb;

  wire [INST_WIDTH - 1:0] inst_if_out;
  wire inst_if_flush;

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
    .en1(imem_enb),

    .clk(clk)
  );

  wire ctrl_imem_en_id_out;

  assign bios_addra = pc_if_out[13:2];
  assign imem_addrb = pc_if_out[15:2];
  assign imem_web = 4'h0;  // FIXME
  assign inst_if_out = inst_if_flush ? 32'b0 : (pc_if_out[30] == 1'b1) ? bios_douta : imem_doutb;
  // when ctrl_imem_en is not asserted, the memory will keep its output value.
  assign imem_enb = ctrl_imem_en_id_out;
  assign bios_ena = ctrl_imem_en_id_out;


  // IF/ID Registers
  wire [  PC_WIDTH - 1:0] pc_id_in;
  wire [INST_WIDTH - 1:0] inst_id_in;

  assign inst_id_in = inst_if_out;

  REGISTER_R_CE #(
    .N(PC_WIDTH),
    .INIT(0)
  ) if_id_pc (
    .d  (pc_if_out),
    .q  (pc_id_in),
    .ce (pc_en),
    .clk(clk),
    .rst(rst)
  );

  wire [DMEM_DWIDTH - 1:0] rs1_id_out, rs2_id_out;
  wire [DMEM_DWIDTH - 1:0] utype_rs1_id_out;
  wire [PC_WIDTH - 1:0] pc_branch_id_out, pc_id_out;
  wire [DMEM_DWIDTH - 1:0] imm_id_out;
  wire [ INST_WIDTH - 1:0] pc_new_id_out;
  wire ctrl_pc_src_id_out, ctrl_reg_we_id_out;
  wire ctrl_mem_write_id_out;
  wire ctrl_mem_read_id_out;
  wire ctrl_id_reg_flush_id_out;
  wire [1:0] ctrl_mem_to_reg_id_out;
  wire [1:0] ctrl_alu_op_id_out;
  wire [1:0] ctrl_alu_src_a_id_out, ctrl_alu_src_b_id_out;
  wire ctrl_forward_a_sel_id_out, ctrl_forward_b_sel_id_out;
  wire ctrl_forward_data_sel_id_out;
  wire ctrl_pc_en_id_out;

  wire ctrl_reg_we_id_in;
  reg [DMEM_DWIDTH - 1:0] rd_id_in;
  wire [4:0] addr_rs1_id_in, addr_rs2_id_in, addr_rd_id_in;

  wire ctrl_csr_we_id_out;
  wire ctrl_csr_rd_id_out;
  wire [11:0] csr_addr_id_out;
  wire [2:0] csr_func_id_out;

  wire [DMEM_DWIDTH - 1:0] alu_ex_out_id_in;
  wire ctrl_id_forward_a_sel, ctrl_id_forward_b_sel;
  wire [4:0] addr_rd_ex_in;

  ID #(
    .PC_WIDTH(PC_WIDTH),
    .INST_WIDTH(INST_WIDTH),
    .DWIDTH(DMEM_DWIDTH)
  ) id (
    .clk(clk),
    .rst(rst),
    // input
    .pc(pc_id_in),
    .addr_rs1(addr_rs1_id_in),
    .addr_rs2(addr_rs2_id_in),
    .addr_rd(addr_rd_id_in),
    .addr_rd_ex_in(addr_rd_ex_in),
    .inst(inst_id_in),
    .reg_we(ctrl_reg_we_id_in),
    .data_rd(rd_id_in),
    .forward_data_in(rd_id_in),
    .forward_a_sel_in(ctrl_id_forward_a_sel),
    .forward_b_sel_in(ctrl_id_forward_b_sel),
    // output
    .data_rs1(rs1_id_out),
    .data_rs2(rs2_id_out),
    .data_imm(imm_id_out),
    .data_pc(pc_id_out),
    .branch_pc_new(pc_new_id_out),
    .ctrl_alu_op(ctrl_alu_op_id_out),
    .ctrl_pc_src(ctrl_pc_src_id_out),
    .ctrl_reg_we(ctrl_reg_we_id_out),
    .ctrl_alu_src_a(ctrl_alu_src_a_id_out),
    .ctrl_alu_src_b(ctrl_alu_src_b_id_out),
    .ctrl_mem_write(ctrl_mem_write_id_out),
    .ctrl_mem_read(ctrl_mem_read_id_out),
    .ctrl_mem_to_reg(ctrl_mem_to_reg_id_out),
    .ctrl_pc_en(ctrl_pc_en_id_out),
    .ctrl_imem_en(ctrl_imem_en_id_out),
    // flush IF/ID inst
    .ctrl_id_reg_flush(ctrl_id_reg_flush_id_out),

    .ctrl_csr_we(ctrl_csr_we_id_out),
    .ctrl_csr_rd(ctrl_csr_rd_id_out),
    .csr_addr(csr_addr_id_out),
    .csr_func(csr_func_id_out)
  );

  // PcSrc doesn't need pipeline
  assign ctrl_pc_src = ctrl_pc_src_id_out;
  assign pc_en = ctrl_pc_en_id_out;
  // Control line to flush instruction in IF/ID stage
  assign inst_if_flush = ctrl_id_reg_flush_id_out;

  assign addr_rs1_id_in = inst_id_in[19:15];
  assign addr_rs2_id_in = inst_id_in[24:20];

  wire ctrl_reg_we_ex_in;
  wire [6:0] opcode_id_in;

  assign opcode_id_in = inst_id_in[6:0];

  FORWARD #(
    .DWIDTH(DMEM_DWIDTH)
  ) forward (
    .rs1_addr_id(addr_rs1_id_in),
    .rs2_addr_id(addr_rs2_id_in),
    .opcode_id(opcode_id_in),
    .rd_addr_ex_in(addr_rd_ex_in),
    .rd_addr_id_in(addr_rd_id_in),
    .ctrl_reg_we_ex_in(ctrl_reg_we_ex_in),
    .ctrl_reg_we_id_in(ctrl_reg_we_id_in),
    .ex_forward_a_sel(ctrl_forward_a_sel_id_out),
    .ex_forward_b_sel(ctrl_forward_b_sel_id_out),
    .ex_forward_data_sel(ctrl_forward_data_sel_id_out),
    .id_forward_a_sel(ctrl_id_forward_a_sel),
    .id_forward_b_sel(ctrl_id_forward_b_sel)
  );

  // ID-EX pipeline

  wire [INST_WIDTH - 1:0] inst_ex_in;
  wire [DMEM_DWIDTH - 1:0] rs1_ex_in, rs2_ex_in;
  wire [DMEM_DWIDTH - 1:0] utype_rs1_ex_in;
  wire [DMEM_DWIDTH - 1:0] imm_ex_in;
  wire [PC_WIDTH - 1:0] pc_ex_in;

  wire ctrl_mem_we_ex_in;
  wire ctrl_mem_rd_ex_in;
  wire [1:0] ctrl_mem_to_reg_ex_in;
  wire [1:0] ctrl_alu_op_ex_in;
  wire [1:0] ctrl_alu_src_a_ex_in, ctrl_alu_src_b_ex_in;
  wire ctrl_forward_a_sel_ex_in, ctrl_forward_b_sel_ex_in;
  wire ctrl_forward_data_sel_ex_in;

  wire ctrl_csr_we_ex_in;
  wire ctrl_csr_rd_ex_in;
  wire [11:0] csr_addr_ex_in;
  wire [2:0] csr_func_ex_in;

  // Note: new pc value doesn't need to use register
  assign pc_new_if_in = pc_new_id_out;

  REGISTER #(
    .N(2)
  ) id_ex_ctrl_alu_src_a (
    .clk(clk),
    .d  (ctrl_alu_src_a_id_out),
    .q  (ctrl_alu_src_a_ex_in)
  );

  REGISTER #(
    .N(2)
  ) id_ex_ctrl_alu_src_b (
    .clk(clk),
    .d  (ctrl_alu_src_b_id_out),
    .q  (ctrl_alu_src_b_ex_in)
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
    .N(2)
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

  REGISTER #(
    .N(1)
  ) id_ex_ctrl_forward_a_sel (
    .clk(clk),
    .d  (ctrl_forward_a_sel_id_out),
    .q  (ctrl_forward_a_sel_ex_in)
  );

  REGISTER #(
    .N(1)
  ) id_ex_ctrl_forward_b_sel (
    .clk(clk),
    .d  (ctrl_forward_b_sel_id_out),
    .q  (ctrl_forward_b_sel_ex_in)
  );

  REGISTER #(
    .N(1)
  ) id_ex_ctrl_forward_data_sel (
    .clk(clk),
    .d  (ctrl_forward_data_sel_id_out),
    .q  (ctrl_forward_data_sel_ex_in)
  );

  REGISTER #(
    .N(1)
  ) id_ex_ctrl_csr_we (
    .clk(clk),
    .d  (ctrl_csr_we_id_out),
    .q  (ctrl_csr_we_ex_in)
  );

  REGISTER #(
    .N(1)
  ) id_ex_ctrl_csr_rd (
    .clk(clk),
    .d  (ctrl_csr_rd_id_out),
    .q  (ctrl_csr_rd_ex_in)
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
  ) id_ex_utype_rs1 (
    .clk(clk),
    .rst(rst),
    .d  (utype_rs1_id_out),
    .q  (utype_rs1_ex_in)
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

  REGISTER_R #(
    .N(12)
  ) id_ex_csr_addr (
    .clk(clk),
    .rst(rst),
    .d  (csr_addr_id_out),
    .q  (csr_addr_ex_in)
  );

  REGISTER_R #(
    .N(3)
  ) id_ex_csr_func (
    .clk(clk),
    .rst(rst),
    .d  (csr_func_id_out),
    .q  (csr_func_ex_in)
  );

  REGISTER_R #(
    .N(PC_WIDTH)
  ) id_ex_pc (
    .clk(clk),
    .rst(rst),
    .d  (pc_id_out),
    .q  (pc_ex_in)
  );

  // EX Stage 

  wire [3:0] alu_func;
  wire [DMEM_DWIDTH - 1:0] alu_out, alu_ex_out;
  wire [DMEM_DWIDTH - 1:0] mem_ex_out;
  wire [DMEM_DWIDTH - 1:0] csr_data_out, csr_ex_data_out;
  wire [INST_WIDTH - 1:0] mem_mask_inst_in;

  assign alu_func = {inst_ex_in[30], inst_ex_in[14:12]};
  assign addr_rd_ex_in = inst_ex_in[11:7];


  EX #(
    .DWIDTH(DMEM_DWIDTH)
  ) ex (
    .clk(clk),
    .data_rs1(rs1_ex_in),
    .data_rs2(rs2_ex_in),
    .data_imm(imm_ex_in),
    .data_pc(pc_ex_in),
    .ctrl_alu_func(alu_func),
    .ctrl_alu_op(ctrl_alu_op_ex_in),
    .ctrl_alu_src_a(ctrl_alu_src_a_ex_in),
    .ctrl_alu_src_b(ctrl_alu_src_b_ex_in),
    .ctrl_forward_a_sel(ctrl_forward_a_sel_ex_in),
    .ctrl_forward_b_sel(ctrl_forward_b_sel_ex_in),
    .forward_data_in(rd_id_in),
    .alu_out(alu_out),

    .ctrl_csr_we(ctrl_csr_we_ex_in),
    .ctrl_csr_rd(ctrl_csr_rd_ex_in),
    .csr_addr(csr_addr_ex_in),
    .csr_func(csr_func_ex_in),
    .csr_data_out(csr_data_out),
    .csr_orig_data_out(csr)
  );

  assign alu_ex_out_id_in = alu_ex_out;

  wire [3:0] mem_wea;
  wire [DMEM_DWIDTH - 1:0] mem_sel_out;
  wire [1:0] ctrl_mem_to_reg_ex_out;

  assign bios_addrb = alu_out[13:2];
  assign dmem_addra = alu_out[15:2];
  assign imem_addra = alu_out[15:2];

  wire [DMEM_DWIDTH - 1:0] mem_gen_din;
  wire [DMEM_DWIDTH - 1:0] mem_din;
  wire [3:0] mem_din_mask;

  assign mem_gen_din = ctrl_forward_data_sel_ex_in ? rd_id_in : rs2_ex_in;

  MEM_DATA_GEN #(
    .DATA_WIDTH(DMEM_DWIDTH)
  ) mem_in_gen (
    .data_in(mem_gen_din),
    .inst_func_in(inst_ex_in[14:12]),
    .byte_addr_in(alu_out[1:0]),
    .data_out(mem_din),
    .wea_out(mem_din_mask)
  );

  wire [DMEM_DWIDTH - 1:0] mmio_addr_in;
  wire [DMEM_DWIDTH - 1:0] mmio_data_in, mmio_data_out;
  wire mmio_we_in;
  // Peripheral data and control signals
  wire [DMEM_DWIDTH - 1:0] mmio_cycle_counter_in, mmio_inst_counter_in;
  wire [7:0] mmio_uart_tx_out, mmio_uart_rx_in;
  wire mmio_uart_tx_ready_in, mmio_uart_rx_valid_in;
  wire mmio_uart_tx_valid_out, mmio_uart_rx_ready_out;
  wire mmio_counter_rst_out;

  // MMIO and other peripherals
  MMIO #(
    .AWIDTH(DMEM_DWIDTH),
    .DWIDTH(DMEM_DWIDTH)
  ) mmio (
    .addr_in(mmio_addr_in),
    .data_in(mmio_data_in),
    .data_uart_rx_in(mmio_uart_rx_in),
    .data_cycle_counter_in(mmio_cycle_counter_in),
    .data_inst_counter_in(mmio_inst_counter_in),
    .ctrl_uart_tx_ready_in(mmio_uart_tx_ready_in),
    .ctrl_uart_rx_valid_in(mmio_uart_rx_valid_in),
    .we_in(mmio_we_in),
    .data_reg_out(mmio_data_out),
    .data_uart_tx_out(mmio_uart_tx_out),
    .ctrl_uart_tx_valid_out(mmio_uart_tx_valid_out),
    .ctrl_uart_rx_ready_out(mmio_uart_rx_ready_out),
    .ctrl_counter_rst_out(mmio_counter_rst_out)
  );

  wire cycle_counter_rst;
  wire [DMEM_DWIDTH - 1:0] cycle_counter_value;

  CYCLE_COUNTER #(.DWIDTH(DMEM_DWIDTH)) cycle_counter (
    .clk(clk),
    .rst(cycle_counter_rst),
    .cycle(cycle_counter_value)
  );
  
  assign cycle_counter_rst = rst | mmio_counter_rst_out;
  assign mmio_cycle_counter_in = cycle_counter_value;

  assign dmem_dina = mem_din;
  assign imem_dina = mem_din;

  assign mem_wea = (ctrl_mem_we_ex_in == 1'b0) ? 4'b0000 : mem_din_mask;
  // Note: see Address Space table
  assign dmem_wea = ((alu_out[31:28] & 4'b1101) == 4'b0001) ? mem_wea : 4'h0;
  // Instruction Memory can be writted only if PC[30] == 1'b1;
  assign imem_wea = (((alu_out[31:28] & 4'b1110) == 4'b0010) & (pc_ex_in[30] == 1'b1)) ? mem_wea : 4'h0;


  wire [1:0] mem_mask_byte_addr;
  wire [2:0] mem_mask_inst_func_in;

  REGISTER #(
    .N(INST_WIDTH)
  ) mem_mask_inst_func (
    .clk(clk),
    .d  (inst_ex_in),
    .q  (mem_mask_inst_in)
  );

  // Registers used to synchronize clock between mem and alu
  REGISTER #(
    .N(DMEM_DWIDTH)
  ) ex_id_alu_out (
    .clk(clk),
    .d  (alu_out),
    .q  (alu_ex_out)
  );

  REGISTER #(
    .N(DMEM_DWIDTH)
  ) ex_id_csr_data_out (
    .clk(clk),
    .d  (csr_data_out),
    .q  (csr_ex_data_out)
  );

  REGISTER #(
    .N(2)
  ) ex_id_ctrl_mem_to_reg (
    .clk(clk),
    .d  (ctrl_mem_to_reg_ex_in),
    .q  (ctrl_mem_to_reg_ex_out)
  );

  // Data out from memory selection
  // Because memory output is synchronise read, so it should use alu_ex_out to
  // decide which one is used.
  assign mem_sel_out = (alu_ex_out[30] == 1'b1) ? bios_doutb : dmem_douta;

  assign mem_mask_byte_addr = alu_ex_out[1:0];
  assign mem_mask_inst_func_in = mem_mask_inst_in[14:12];

  // Select part of mem_out according to byte address
  MEM_DATA_MASK #(
    .DATA_WIDTH(DMEM_DWIDTH)
  ) mem_out_mask (
    .data_in(mem_sel_out),
    .inst_func_in(mem_mask_inst_func_in),
    .byte_addr_in(mem_mask_byte_addr),
    .data_out(mem_ex_out)
  );

  // EX output selection
  always @(*) begin
    case (ctrl_mem_to_reg_ex_out)
      2'b00:   rd_id_in = alu_ex_out;
      2'b01:   rd_id_in = csr_data_out;
      2'b10:   rd_id_in = mem_ex_out;
      default: rd_id_in = alu_ex_out;
    endcase
  end

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

endmodule
