`include "Opcode.vh"

module CSR #(
  parameter DWIDTH = 32
) (
  input clk,
  input we,
  input rd,
  input [11:0] addr,
  input [2:0] func, 
  input [DWIDTH - 1:0] data_in,
  output [DWIDTH - 1:0] data_out
);

  wire [DWIDTH - 1:0] data_csr_rf_out;

  ASYNC_RAM #(
    .AWIDTH(12),
    .DWIDTH(DWIDTH)
  ) csr_rf (
    .addr(addr),  // input
    .we(we),    // input

    .q(data_csr_rf_out),  // output
    .d(data_in),

    .clk(clk)
  );

  assign data_out = data_csr_rf_out;

endmodule