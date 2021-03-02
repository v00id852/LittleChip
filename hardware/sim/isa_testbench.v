`timescale 1ns/1ns

module isa_testbench();
    reg clk, rst;
    parameter CPU_CLOCK_PERIOD = 20;
    parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

    initial clk = 0;
    always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

    wire [31:0] csr;

    Riscv151 # (
        .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ),
        .RESET_PC(32'h1000_0000)
    ) CPU (
        .clk(clk),
        .rst(rst),
        .FPGA_SERIAL_RX(),
        .FPGA_SERIAL_TX(),
        .csr(csr)
    );

    reg done = 0;
    reg [31:0] cycle = 0;
    reg [255:0] MIF_FILE;
    initial begin
        if (!$value$plusargs("MIF_FILE=%s", MIF_FILE)) begin
            $display("Must supply mif_file!");
            $finish();
        end

        $readmemh(MIF_FILE, CPU.dmem.mem);
        $readmemh(MIF_FILE, CPU.imem.mem);

        rst = 0;

        // Reset the CPU
        rst = 1;
        repeat (30) @(posedge clk); #1; // Hold reset for 30 cycles
        rst = 0;

        // Wait until csr[0] is asserted
        while (csr[0] !== 1'b1) begin
            @(posedge clk);
        end
        done = 1;

        if (csr[0] === 1'b1 && csr[31:1] === 31'd0) begin
            $display("[PASSED] - %s in %d simulation cycles", MIF_FILE, cycle);
        end else begin
            $display("[FAILED] - %s. Failed test: %d", MIF_FILE, csr[31:1]);
        end
        $finish();
    end

    initial begin
        while (rst == 1) begin
            @(posedge clk);
        end

        // Timeout in 10000 cycles
        for (cycle = 0; cycle < 10000; cycle = cycle + 1) begin
            if (!done) @(posedge clk);
        end
        if (!done) begin
            $display("[FAILED] - %s. Timing out", MIF_FILE);
            $finish();
        end
    end

endmodule
