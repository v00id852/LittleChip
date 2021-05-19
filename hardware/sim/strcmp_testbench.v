`timescale 1ns/1ns
`include "mem_path.vh"

module strcmp_testbench();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20;
  parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

  localparam TIMEOUT_CYCLE = 1000;

  initial clk = 0;
  always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

  wire [31:0] csr;
  Riscv151 # (
    .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ),
    .RESET_PC(32'h1000_0000)
  ) CPU (
    .clk(clk),
    .rst(rst),
    .FPGA_SERIAL_RX(), // input
    .FPGA_SERIAL_TX(), // output
    .csr(csr)
  );

  reg [31:0] cycle;
  always @(posedge clk) begin
    if (rst === 1)
      cycle <= 0;
    else
      cycle <= cycle + 1;
  end

  initial begin
    $dumpfile("strcmp_testbench.vcd");
    $dumpvars;

    #1;
    $readmemh("strcmp.mif", `IMEM_PATH.mem);
    $readmemh("strcmp.mif", `DMEM_PATH.mem);

    rst = 1;

    // Hold reset for a while
    repeat (10) @(posedge clk);

    @(negedge clk);
    rst = 0;

    // Delay for some time
    repeat (10) @(posedge clk);

    // Wait until csr is updated
    wait (csr !== 0);

    if (csr === 32'b1) begin
      $display("[%d sim. cycles] CSR test PASSED! Strings matched.", cycle);
    end else begin
      $display("[%d sim. cycles] CSR test FAILED! Strings mismatched.", cycle);
    end

    #100;
    $finish();
  end

  initial begin
    repeat (TIMEOUT_CYCLE) @(posedge clk);
    $display("Timeout!");
    $finish();
  end

endmodule
