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

  output [DWIDTH - 1:0] data_reg_out,
  // Peripheral data out
  output [7:0] data_uart_tx_out,
  // Peripheral control out
  output ctrl_uart_tx_valid_out,
  output ctrl_uart_rx_ready_out,
  output ctrl_counter_rst_out
);

  reg [DWIDTH - 1:0] data_reg_out;
  reg ctrl_counter_rst_out;
  reg ctrl_uart_tx_valid_out, ctrl_uart_rx_ready_out;

  always @(*) begin
    if (addr_in == {{(AWIDTH - 32) {1'b0}}, 32'h80000010}) begin
      data_reg_out = data_cycle_counter_in;
    end else if (addr_in == {{(AWIDTH - 32) {1'b0}}, 32'h80000014}) begin
      // Instruction counter
      data_reg_out = data_inst_counter_in;
    end else if (ctrl_uart_rx_ready_out && ctrl_uart_rx_valid_in) begin
      // Uart receiver data
      data_reg_out = data_uart_rx_in;
    end else if (addr_in == {{(AWIDTH - 32) {1'b0}}, 32'h80000000}) begin
      // Uart control
      data_reg_out = {{(DWIDTH - 2) {1'b0}}, ctrl_uart_rx_valid_in, ctrl_uart_tx_ready_in};
    end else begin
      data_reg_out = {AWIDTH{1'b0}};
    end
  end

  // Reset instruction counter and cycle counter
  always @(*) begin
    if ((addr_in == {{(AWIDTH - 32) {1'b0}}, 32'h80000018}) && we_in) begin
      ctrl_counter_rst_out = 1'b1;
    end else begin
      ctrl_counter_rst_out = 1'b0;
    end
  end

  assign data_uart_tx_out = data_in & 32'h0000_00ff;

  // Uart transceiver valid signal
  always @(*) begin
    if ((addr_in == {{(AWIDTH - 32) {1'b0}}, 32'h80000008}) && we_in) begin
      // UART write data;
      if (ctrl_uart_tx_ready_in) ctrl_uart_tx_valid_out = 1'b1;
      else ctrl_uart_tx_valid_out = 1'b0;
    end else begin
      ctrl_uart_tx_valid_out = 1'b0;
    end
  end

  // Uart receiver ready signal
  always @(*) begin
    if ((addr_in == {{(AWIDTH - 32) {1'b0}}, 32'h80000004}) && re_in) begin
      ctrl_uart_rx_ready_out = 1'b1;
    end else begin
      ctrl_uart_rx_ready_out = 1'b0;
    end
  end


endmodule
