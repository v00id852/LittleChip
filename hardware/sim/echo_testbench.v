`timescale 1ns/1ns

module echo_testbench();
    reg clk, rst;
    parameter CPU_CLOCK_PERIOD = 20;
    parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;
    localparam BAUD_RATE       = 115_200;
    localparam BAUD_PERIOD     = 1_000_000_000 / BAUD_RATE; // 8680.55 ns

    localparam CHAR0     = 8'h61; // ~ 'a'
    localparam NUM_CHARS = 10;

    initial clk = 0;
    always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

    reg  serial_in;
    wire serial_out;

    Riscv151 # (
        .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ),
        .BIOS_MEM_HEX_FILE("echo.mif")
    ) CPU (
        .clk(clk),
        .rst(rst),
        .FPGA_SERIAL_RX(serial_in),   // input
        .FPGA_SERIAL_TX(serial_out),  // output
        .csr()
    );

    integer i, j, c, c1, c2;
    reg done = 0;
    reg [31:0] cycle = 0;
    integer num_mismatches = 0;

    // this holds characters sent by the host via serial line
    reg [7:0] chars_from_host [NUM_CHARS-1:0];
    // this holds characters received by the host via serial line
    reg [9:0] chars_to_host   [NUM_CHARS-1:0];

    // initialize test vectors
    initial begin
        #0
        for (c = 0; c < NUM_CHARS; c = c + 1) begin
           chars_from_host[c] = CHAR0 + c;
        end
    end

    // Host off-chip UART --> FPGA on-chip UART (receiver)
    // The host (testbench) sends a character to the CPU via the serial line
    task host_to_fpga;
        begin

            for (c1 = 0; c1 < NUM_CHARS; c1 = c1 + 1) begin
                serial_in = 0;
                #(BAUD_PERIOD);
                // Data bits (payload)
                for (i = 0; i < 8; i = i + 1) begin
                    serial_in = chars_from_host[c1][i];
                    #(BAUD_PERIOD);
                end
                // Stop bit
                serial_in = 1;
                #(BAUD_PERIOD);

                $display("[time %t, sim. cycle %d] [Host (tb) --> FPGA_SERIAL_RX] Sent char 8'h%h",
                         $time, cycle, chars_from_host[c1]);
            end
        end
    endtask

    // Host off-chip UART <-- FPGA on-chip UART (transmitter)
    // The host (testbench) expects to receive a character from the CPU via the serial line (echoed)
    task fpga_to_host;
        begin

            for (c2 = 0; c2 < NUM_CHARS; c2 = c2 + 1) begin
                // Wait until serial_out is LOW (start of transaction)
                while (serial_out == 1) begin
                    @(posedge clk);
                end

                for (j = 0; j < 10; j = j + 1) begin
                    chars_to_host[c2][j] = serial_out;
                    #(BAUD_PERIOD);
                end

                $display("[time %t, sim. cycle %d] [Host (tb) <-- FPGA_SERIAL_TX] Got char: start_bit=%b, payload=8'h%h, stop_bit=%b",
                         $time, cycle, chars_to_host[c2][0], chars_to_host[c2][8:1], chars_to_host[c2][9]);
            end
        end
    endtask

    initial begin
        #0;
        rst = 1;
        serial_in = 1;

        // Hold reset for a while
        repeat (10) @(posedge clk);

        rst = 0;

        // Delay for some time
        repeat (10) @(posedge clk);

        fork
            begin
                host_to_fpga();
            end
            begin
                fpga_to_host();
            end
        join

        done = 1;

        // Check results
        for (c = 0; c < NUM_CHARS; c = c + 1) begin
            if (chars_from_host[c] !== chars_to_host[c][8:1]) begin
                $display("Mismatches at char %d: char_from_host=%h, char_to_host=%h",
                         c, chars_from_host[c], chars_to_host[c][8:1]);
                num_mismatches = num_mismatches + 1;
            end
        end

        if (num_mismatches > 0)
            $display("Test failed");
        else
            $display("Test passed!");

        $finish();
        #100;
    end

    initial begin
        while (rst == 1) begin
            @(posedge clk);
        end

        // Timeout in 10000 * NUM_CHARS cycles
        for (cycle = 0; cycle < 10000 * NUM_CHARS; cycle = cycle + 1) begin
            if (!done) @(posedge clk);
        end

        if (!done) begin
            $display("[FAILED] Timing out");
            $finish();
        end
    end

endmodule
