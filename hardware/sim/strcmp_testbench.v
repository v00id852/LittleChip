`timescale 1ns/1ns

module strcmp_testbench();
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
        .FPGA_SERIAL_RX(), // input
        .FPGA_SERIAL_TX(), // output
        .csr(csr)
    );

    reg done = 0;
    reg [31:0] cycle = 0;

    initial begin
        #1;
        $readmemh("strcmp.mif", CPU.imem.mem);
        $readmemh("strcmp.mif", CPU.dmem.mem);

        rst = 1;

        // Hold reset for a while
        repeat (10) @(posedge clk);

        rst = 0;

        // Delay for some time
        repeat (10) @(posedge clk);

        // Wait until csr is updated
        while (csr === 0) begin
            @(posedge clk);
        end
        done = 1;

        if (csr[0] === 1'b1 && csr[31:1] === 31'd0) begin
            $display("[%d sim. cycles] CSR test PASSED! Strings matched.", cycle);
        end else begin
            $display("[%d sim. cycles] CSR test FAILED! Strings mismatched.", cycle);
        end

        #100;
        $finish();
    end

    initial begin
        while (rst == 1) begin
            @(posedge clk);
        end

        for (cycle = 0; cycle < 1000; cycle = cycle + 1) begin
            if (!done) @(posedge clk);
        end

        if (!done) begin
            $display("[FAILED] Timing out");
            $finish();
        end
    end

endmodule
