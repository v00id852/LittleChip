
module RF # (
  parameter AWIDTH = 5,
  parameter DWIDTH = 32
) (
  input clk,

  input               we0,
  input  [AWIDTH-1:0] addr0,
  input  [DWIDTH-1:0] din0,

  input  [AWIDTH-1:0] addr1,
  output [DWIDTH-1:0] dout1,

  input  [AWIDTH-1:0] addr2,
  output [DWIDTH-1:0] dout2
);

  // TODO: Your code to implement a RISC-V RegFile (2 async-read ports, 1 sync-write port)
  // Note that writing to RF[0] does not have any effect
  // Some initial code has been provide to you, but please feel free to change them
  // as you see fit

  localparam NUM_REGS = (1 << AWIDTH);

  wire [DWIDTH-1:0] rf_entry_next  [NUM_REGS-1:0];
  wire [DWIDTH-1:0] rf_entry_value [NUM_REGS-1:0];
  wire              rf_entry_ce    [NUM_REGS-1:0];

  genvar i;
  generate for (i = 0; i < NUM_REGS; i = i + 1) begin
    REGISTER_CE #(.N(DWIDTH)) rf_entry (
      .clk(clk),
      .ce(rf_entry_ce[i]),
      .d(rf_entry_next[i]),
      .q(rf_entry_value[i])
    );

    assign rf_entry_ce[i]   = 0;
    assign rf_entry_next[i] = 0;
  end
  endgenerate

  assign dout1 = 0;
  assign dout2 = 0;

endmodule
