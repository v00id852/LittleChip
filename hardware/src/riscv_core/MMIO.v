module MMIO #(
  parameter AWIDTH = 32,
  parameter DWIDTH = 32
) (
  input [AWIDTH - 1:0] addr_in,
  input [DWIDTH - 1:0] cycle_counter_in,
  input [DWIDTH - 1:0] inst_counter_in,
  input we_in,
  output counter_rst_out,
  output [DWIDTH - 1:0] data_out
);

  reg [DWIDTH - 1:0] data_out;
  reg [DWIDTH - 1:0] counter_rst_out;

  always @(*) begin
    if (addr == {{(AWIDTH - 32){1'b0}}, 32'h80000010}) begin
      data_out = cycle_counter_in;
    end else begin
      data_out = 32'b0;
    end
  end

  always @(*) begin
    if ((addr == {{(AWIDTH - 32){1'b0}}, 32'h80000018}) && we) begin
      counter_rst_out = 1'b1;
    end else begin
      counter_rst_out = 1'b0;
    end
  end
  

endmodule