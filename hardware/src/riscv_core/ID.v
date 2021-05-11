module ID #(
  parameter IWIDTH = 32,
  parameter DWIDTH = 32
) (
  input clk,
  input rst,
  input reg_we,
  input [IWIDTH - 1:0] inst,
  input [DWIDTH - 1:0] rd_data,
  output [DWIDTH - 1:0] rs1_data, rs2_data
);

  
  wire rf_we;
  wire [4:0]  rf_ra1, rf_ra2, rf_wa;
  wire [31:0] rf_wd;
  wire [31:0] rf_rd1, rf_rd2;

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

  // register 1
  assign rf_ra1 = inst[19:15];
  // register 2
  assign rf_ra2 = inst[24:20];
  // register rd
  assign rf_wa = inst[11:7];
  // register files write enable
  assign rf_we = reg_we;
  
  

endmodule

