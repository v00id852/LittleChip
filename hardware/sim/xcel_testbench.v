`timescale 1ns/1ns

module xcel_testbench();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20;
  parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

  initial clk = 0;
  always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

  localparam TIMEOUT_CYCLE = 10000_000;

  localparam DWIDTH     = 8;
  localparam IFM_DIM    = 28;
  localparam IFM_DEPTH  = 2;
  localparam WT_DIM     = 5;
  localparam OFM_DIM    = 24;
  localparam OFM_DEPTH  = 2;

  localparam IFM_LEN = IFM_DEPTH * IFM_DIM * IFM_DIM;
  localparam WT_LEN  = OFM_DEPTH * IFM_DEPTH * WT_DIM * WT_DIM;
  localparam OFM_LEN = OFM_DEPTH * OFM_DIM * OFM_DIM;

  localparam AXI_AWIDTH = 32;
  localparam AXI_DWIDTH = 32;

  wire xcel_read_request_valid;
  wire xcel_read_request_ready;
  wire [AXI_AWIDTH-1:0] xcel_read_addr;
  wire [31:0] xcel_read_len;
  wire [2:0] xcel_read_size;
  wire [1:0] xcel_read_burst;
  wire [AXI_DWIDTH-1:0] xcel_read_data;
  wire xcel_read_data_valid;
  wire xcel_read_data_ready;

  wire xcel_write_request_valid;
  wire xcel_write_request_ready;
  wire [AXI_AWIDTH-1:0] xcel_write_addr;
  wire [31:0] xcel_write_len;
  wire [2:0] xcel_write_size;
  wire [1:0] xcel_write_burst;
  wire [AXI_DWIDTH-1:0] xcel_write_data;
  wire xcel_write_data_valid;
  wire xcel_write_data_ready;

  reg  xcel_start;
  wire xcel_idle;
  wire xcel_done;

  wire [31:0] wt_ddr_addr  = 0;
  wire [31:0] ifm_ddr_addr = ((WT_LEN+3)/4) << 2;
  wire [31:0] ofm_ddr_addr = ((WT_LEN+3)/4 + (IFM_LEN+3)/4) << 2;

  wire [31:0] ifm_dim   = IFM_DIM;
  wire [31:0] ifm_depth = IFM_DEPTH;
  wire [31:0] ofm_dim   = OFM_DIM;
  wire [31:0] ofm_depth = OFM_DEPTH;

  xcel_naive #(
    .AXI_AWIDTH(AXI_AWIDTH),
    .AXI_DWIDTH(AXI_DWIDTH),
    .WT_DIM(WT_DIM)
  ) dut (
    .clk(clk),
    .rst(rst),

    .xcel_read_request_valid(xcel_read_request_valid),   // output
    .xcel_read_request_ready(xcel_read_request_ready),   // input
    .xcel_read_addr(xcel_read_addr),                     // output
    .xcel_read_len(xcel_read_len),                       // output
    .xcel_read_size(xcel_read_size),                     // output
    .xcel_read_burst(xcel_read_burst),                   // output
    .xcel_read_data(xcel_read_data),                     // input
    .xcel_read_data_valid(xcel_read_data_valid),         // input
    .xcel_read_data_ready(xcel_read_data_ready),         // output

    .xcel_write_request_valid(xcel_write_request_valid), // output
    .xcel_write_request_ready(xcel_write_request_ready), // input
    .xcel_write_addr(xcel_write_addr),                   // output
    .xcel_write_len(xcel_write_len),                     // output
    .xcel_write_size(xcel_write_size),                   // output
    .xcel_write_burst(xcel_write_burst),                 // output
    .xcel_write_data(xcel_write_data),                   // output
    .xcel_write_data_valid(xcel_write_data_valid),       // output
    .xcel_write_data_ready(xcel_write_data_ready),       // input

    .xcel_start(xcel_start), // input
    .xcel_done(xcel_done),   // output
    .xcel_idle(xcel_idle),   // output

    .ifm_ddr_addr(ifm_ddr_addr), // input
    .wt_ddr_addr(wt_ddr_addr),   // input
    .ofm_ddr_addr(ofm_ddr_addr), // input

    .ifm_dim(ifm_dim),     // input
    .ifm_depth(ifm_depth), // input
    .ofm_dim(ofm_dim),     // input
    .ofm_depth(ofm_depth)  // input
  );

  localparam MEM_AWIDTH = 14;

  mem_model #(
    .AXI_AWIDTH(AXI_AWIDTH),
    .AXI_DWIDTH(AXI_DWIDTH),
    .MEM_AWIDTH(MEM_AWIDTH)
  ) mm_unit (
    .clk(clk),
    .rst(rst),

    .read_request_valid(xcel_read_request_valid),   // input
    .read_request_ready(xcel_read_request_ready),   // output
    .read_request_addr(xcel_read_addr),             // input
    .read_len(xcel_read_len),                       // input
    .read_size(xcel_read_size),                     // input
    .read_data(xcel_read_data),                     // output
    .read_data_valid(xcel_read_data_valid),         // output
    .read_data_ready(xcel_read_data_ready),         // input

    .write_request_valid(xcel_write_request_valid), // input
    .write_request_ready(xcel_write_request_ready), // output
    .write_request_addr(xcel_write_addr),           // input
    .write_len(xcel_write_len),                     // input
    .write_size(xcel_write_size),                   // input
    .write_data(xcel_write_data),                   // output
    .write_data_valid(xcel_write_data_valid),       // output
    .write_data_ready(xcel_write_data_ready)        // input
  );


  integer ifm_data[IFM_DEPTH*IFM_DIM*IFM_DIM-1:0];
  integer wt_data[OFM_DEPTH*IFM_DEPTH * WT_DIM*WT_DIM-1:0];
  integer ofm_sw_data[OFM_DEPTH*OFM_DIM*OFM_DIM-1:0];
  integer tmp;

  integer f, d, i, j, m, n;
  initial begin
    #0;
    // init ifm and weight data
    // include neg numbers to test signness
    for (d = 0; d < IFM_DEPTH; d = d + 1) begin
      for (i = 0; i < IFM_DIM; i = i + 1) begin
        for (j = 0; j < IFM_DIM; j = j + 1) begin
          ifm_data[d * IFM_DIM * IFM_DIM + i * IFM_DIM + j] = (d * IFM_DIM * IFM_DIM + i * IFM_DIM + j) % 256 - 128;
        end
      end
    end

    for (f = 0; f < OFM_DEPTH; f = f + 1) begin
      for (d = 0; d < IFM_DEPTH; d = d + 1) begin
        for (m = 0; m < WT_DIM; m = m + 1) begin
          for (n = 0; n < WT_DIM; n = n + 1) begin
            wt_data[f * IFM_DEPTH * WT_DIM * WT_DIM + d * WT_DIM * WT_DIM + m * WT_DIM + n] = (n % 2 == 0) ? -(f + d + m + n) : (f + d + m + n);
          end
        end
      end
    end

    for (f = 0; f < OFM_DEPTH; f = f + 1) begin
      for (i = 0; i < OFM_DIM; i = i + 1) begin
        for (j = 0; j < OFM_DIM; j = j + 1) begin
          ofm_sw_data[f * OFM_DIM * OFM_DIM + i * OFM_DIM + j] = 0;
        end
      end
    end
  end

  initial begin
    #1;
    // Software implementation of conv3D
    for (f = 0; f < OFM_DEPTH; f = f + 1) begin
      for (d = 0; d < IFM_DEPTH; d = d + 1) begin
        for (i = 0; i < OFM_DIM; i = i + 1) begin
          for (j = 0; j < OFM_DIM; j = j + 1) begin
            tmp = 0;

            for (m = 0; m < WT_DIM; m = m + 1) begin
              for (n = 0; n < WT_DIM; n = n + 1) begin
                tmp = tmp +
                  ifm_data[d * IFM_DIM * IFM_DIM + (i + m) * IFM_DIM + (j + n)] *
                  wt_data[f * IFM_DEPTH * WT_DIM * WT_DIM + d * WT_DIM * WT_DIM + m * WT_DIM + n];
              end // m
            end // n
            ofm_sw_data[f * OFM_DIM * OFM_DIM + i * OFM_DIM + j] = ofm_sw_data[f * OFM_DIM * OFM_DIM + i * OFM_DIM + j] + tmp;

          end // j
        end // i
      end // d
    end // f

  end

  task init_data;
    begin
      for (i = 0; i < WT_LEN+3; i = i + 4) begin
        mm_unit.buffer.mem[i/4] = {wt_data[i + 3][7:0],
                                   wt_data[i + 2][7:0],
                                   wt_data[i + 1][7:0],
                                   wt_data[i + 0][7:0]};
      end

      for (i = 0; i < IFM_LEN+3; i = i + 4) begin
        mm_unit.buffer.mem[(WT_LEN+3)/4 + i/4] = {ifm_data[i + 3][7:0],
                                                  ifm_data[i + 2][7:0],
                                                  ifm_data[i + 1][7:0],
                                                  ifm_data[i + 0][7:0]};
      end

      for (i = 0; i < OFM_LEN; i = i + 1) begin
        mm_unit.buffer.mem[(WT_LEN+3)/4 + (IFM_LEN+3)/4 + i] = $random;//ofm_sw_data[i];
      end
    end
  endtask

  integer num_mismatches = 0;

  task check_result;
    begin
      for (i = 0; i < OFM_LEN; i = i + 1) begin
        if (mm_unit.buffer.mem[(WT_LEN+3)/4 + (IFM_LEN+3)/4 + i] !== ofm_sw_data[i]) begin
          num_mismatches = num_mismatches + 1;
          $display("Mismatch at %d: expected %d, got %d",
                   i, ofm_sw_data[i], mm_unit.buffer.mem[(WT_LEN+3)/4 + (IFM_LEN+3)/4 + i]);
        end
      end
      if (num_mismatches == 0)
        $display("Test passed!");
      else
        $display("Test failed! Num. mismatches: %d", num_mismatches);
    end
  endtask

  reg [31:0] sim_cycle;
  reg xcel_running;

  always @(posedge clk) begin
    if (rst === 1'b1) begin
      xcel_running <= 1'b0;
      sim_cycle <= 1'b0;
    end
    else begin
      if (xcel_start === 1'b1)
        xcel_running <= 1'b1;
      if (xcel_running === 1'b1)
        sim_cycle <= sim_cycle + 1;
    end
  end

  integer k;

  initial begin
    //$dumpfile("xcel_testbench.vcd");
    //$dumpvars;

    #0;
    rst = 1'b1;
    xcel_start = 1'b0;
    init_data();

    repeat (10) @(posedge clk);

    @(negedge clk);
    rst = 1'b0;

    // Run twice to make sure everything is reset properly
    for (k = 0; k < 2; k = k + 1) begin
      @(negedge clk);
      xcel_start = 1'b1;
      $display("Start!");

      @(negedge clk);
      xcel_start = 1'b0;

      wait (xcel_done === 1'b1);
      @(posedge clk); #1;

      check_result();

      $display("Done in %d simulation cycles!", sim_cycle);
    end

    $finish();
  end

  initial begin
    repeat (TIMEOUT_CYCLE) @(posedge clk);
    $display("Timeout!");
    $finish();
  end
 
endmodule
