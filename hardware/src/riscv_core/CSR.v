module CSR #(
  parameter DWIDTH = 32
) (
  input clk,
  input we,
  input [11:0] addr,
  input [DWIDTH - 1:0] data_in,
  output [DWIDTH - 1:0] data_out
);

  ASYNC_RAM #(
    .AWIDTH(12),
    .DWIDTH(DWIDTH)
  ) csr_rf (
    .addr(addr),  // input
    .we(we),    // input

    .q(data_out),  // output
    .d(data_in),

    .clk(clk)
  );

endmodule