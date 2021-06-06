module MMIO #(
  parameter AWIDTH = 32,
  parameter DWIDTH = 32
) (
  input [AWIDTH - 1:0] addr_in,
  input [DWIDTH - 1:0] data_in,
  input re_in,
  input we_in,
  // Peripheral data in
  input [7:0] data_uart_rx_in,
  input [DWIDTH - 1:0] data_cycle_counter_in,
  input [DWIDTH - 1:0] data_inst_counter_in,
  // Peripheral data in
  input ctrl_uart_tx_ready_in,
  input ctrl_uart_rx_valid_in,

  output reg [DWIDTH - 1:0] data_reg_out,
  // Peripheral data out
  output [7:0] data_uart_tx_out,
  // Peripheral control out
  output ctrl_uart_tx_valid_out,
  output ctrl_uart_rx_ready_out,
  output ctrl_counter_rst_out
);


  wire is_mmio_addr;
  assign is_mmio_addr = (addr_in[31] == 1'b1);

  always @(*) begin
    if (is_mmio_addr) begin
      if (addr_in[7:0] == 8'h10) begin
        data_reg_out = data_cycle_counter_in;
      end else if (addr_in[7:0] == 8'h14) begin
        // Instruction counter
        data_reg_out = data_inst_counter_in;
      end else if (ctrl_uart_rx_ready_out && ctrl_uart_rx_valid_in) begin
        // Uart receiver data
        data_reg_out = data_uart_rx_in;
      end else if (addr_in[7:0] == 8'h00) begin
        // Uart control
        data_reg_out = {{(DWIDTH - 2) {1'b0}}, ctrl_uart_rx_valid_in, ctrl_uart_tx_ready_in};
      end
    end else begin
      data_reg_out = {AWIDTH{1'b0}};
    end
  end

  assign ctrl_counter_rst_out = (is_mmio_addr && addr_in[7:0] == 8'h18 && we_in);
  assign ctrl_uart_tx_valid_out = (is_mmio_addr && addr_in[7:0] == 8'h08 && we_in && ctrl_uart_tx_ready_in);
  assign ctrl_uart_rx_ready_out = (is_mmio_addr && addr_in[7:0] == 8'h04 && re_in);

  assign data_uart_tx_out = data_in & 32'h0000_00ff;


endmodule
