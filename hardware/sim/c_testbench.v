`timescale 1ns/1ns
`include "mem_path.vh"

module c_testbench();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20;
  parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;
  localparam BAUD_RATE       = 115_200;
  localparam BAUD_PERIOD     = 1_000_000_000 / BAUD_RATE; // 8680.55 ns

  localparam TIMEOUT_CYCLE = 100_000;

  initial clk = 0;
  always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

  reg  serial_in;
  wire serial_out;
  wire [31:0] csr;
  Riscv151 # (
    .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ),
    .RESET_PC(32'h1000_0000)
  ) CPU (
    .clk(clk),
    .rst(rst),
    .FPGA_SERIAL_RX(serial_in),   // input
    .FPGA_SERIAL_TX(serial_out),  // output
    .csr(csr)
  );

  integer i, j;
  reg [31:0] cycle;
  always @(posedge clk) begin
    if (rst === 1)
      cycle <= 0;
    else
      cycle <= cycle + 1;
  end

  // Host off-chip UART --> FPGA on-chip UART (receiver)
  // The host (testbench) sends a character to the CPU via the serial line
  task host_to_fpga;
    input [7:0] char_in;
    begin
      serial_in = 0;
      #(BAUD_PERIOD);
      // Data bits (payload)
      for (i = 0; i < 8; i = i + 1) begin
        serial_in = char_in[i];
        #(BAUD_PERIOD);
      end
      // Stop bit
      serial_in = 1;
      #(BAUD_PERIOD);

      $display("[time %t, sim. cycle %d] [Host (tb) --> FPGA_SERIAL_RX] Sent char 8'h%h",
               $time, cycle, char_in);
    end
  endtask

  reg [9:0] char_out;
  reg [63:0] test_status;

  // Host off-chip UART <-- FPGA on-chip UART (transmitter)
  // The host (testbench) expects to receive a character from the CPU via the serial line 
  task fpga_to_host;
    input [7:0] expected_char;
    begin
      // Wait until serial_out is LOW (start of transaction)
      while (serial_out === 1) begin
        @(posedge clk);
      end

      for (j = 0; j < 10; j = j + 1) begin
        char_out[j] = serial_out;
        #(BAUD_PERIOD);
      end

      if (expected_char === char_out[8:1])
        test_status = "PASSED";
      else
        test_status = "FAILED";

      $display("[time %t, sim. cycle %d] [Host (tb) <-- FPGA_SERIAL_TX] Got char 8'h%h, expected 8'h%h, == %s [ %s ]",
               $time, cycle, char_out[8:1], expected_char, expected_char, test_status);
    end
  endtask

  initial begin
    $dumpfile("c_testbench.vcd");
    $dumpvars;

    #1;
    $readmemh("c_test.mif", `IMEM_PATH.mem);
    $readmemh("c_test.mif", `DMEM_PATH.mem);

    rst = 1;
    serial_in = 1;

    // Hold reset for a while
    repeat (10) @(posedge clk);

    @(negedge clk);
    rst = 0;

    // Delay for some time
    repeat (10) @(posedge clk);

    $display("[TEST 1] Expect to see: \\r\\n151> ");

    fpga_to_host(8'h0d); // \r
    fpga_to_host(8'h0a); // \n
    fpga_to_host(8'h31); // 1
    fpga_to_host(8'h35); // 5
    fpga_to_host(8'h31); // 1
    fpga_to_host(8'h3e); // >
    fpga_to_host(8'h20); // [space]

    $display("[TEST 2]");
    fork
      begin
        host_to_fpga(8'h78); // 'x'
        host_to_fpga(8'h79); // 'y'
        host_to_fpga(8'h7a); // 'z'
        host_to_fpga(8'h0d); // '\r'
      end
      begin
        // echo back the input characters ...
        fpga_to_host(8'h78); // 'x'
        fpga_to_host(8'h79); // 'y'
        fpga_to_host(8'h7a); // 'z'
        fpga_to_host(8'h0d); // '\r'
      end
    join

    // Wait until csr is updated
    wait (csr !== 0)

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
