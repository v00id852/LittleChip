`include "axi_consts.vh"
`include "lenet_consts.vh"

// this is really naive, don't try this at home

// This module implements conv3D
// The weight parameter is statically configured (Verilog parameters)
// The IFM and OFM paramters (dimension, depth) are set by the
// software program runnning on the CPU via Memory-mapped IO addresses
// (dynamically configured)
module xcel_naive #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter WT_DIM     = 5
) (
  input clk,
  input rst,

  // (simplified) read request address and read data channel for
  // interfacing with AXI adapter read
  output                  xcel_read_request_valid,
  input                   xcel_read_request_ready,
  output [AXI_AWIDTH-1:0] xcel_read_addr,
  output [31:0]           xcel_read_len,
  output [2:0]            xcel_read_size,
  output [1:0]            xcel_read_burst,
  input  [AXI_DWIDTH-1:0] xcel_read_data,
  input                   xcel_read_data_valid,
  output                  xcel_read_data_ready,

  // (simplified) write request address and write data channel for
  // interfacing with AXI adapter write
  output                  xcel_write_request_valid,
  input                   xcel_write_request_ready,
  output [AXI_AWIDTH-1:0] xcel_write_addr,
  output [31:0]           xcel_write_len,
  output [2:0]            xcel_write_size,
  output [1:0]            xcel_write_burst,
  output [AXI_DWIDTH-1:0] xcel_write_data,
  output                  xcel_write_data_valid,
  input                   xcel_write_data_ready,

  // For interfacing with IO controller logic in Riscv151
  input  xcel_start,
  output xcel_done,
  output xcel_idle,

  input [31:0] ifm_ddr_addr, // IFM address in DDR
  input [31:0] wt_ddr_addr,  // WT address in DDR
  input [31:0] ofm_ddr_addr, // OFM address in DDR

  input [31:0] ifm_dim,
  input [31:0] ifm_depth,
  input [31:0] ofm_dim,
  input [31:0] ofm_depth
);

  localparam integer WT_SIZE = WT_DIM * WT_DIM;

  wire [31:0] ifm_size;  // ifm_dim * ifm_dim
  wire [31:0] ifm_len;   // ifm_depth * ifm_dim * ifm_dim

  wire [31:0] wt_volume; // ifm_depth * WT_DIM * WT_DIM
  wire [31:0] wt_len;    // ofm_depth * ifm_depth * WT_DIM * WT_DIM

  wire [31:0] ofm_size;  // ofm_dim * ofm_dim
  wire [31:0] ofm_len;   // ofm_depth * ofm_dim * ofm_dim

  // Register the configuration from Riscv151 IO
  REGISTER #(.N(32)) ifm_size_reg (
    .clk(clk),
    .d(ifm_dim * ifm_dim),
    .q(ifm_size)
  );

  REGISTER #(.N(32)) ifm_len_reg (
    .clk(clk),
    .d(ifm_size * ifm_depth),
    .q(ifm_len)
  );

  REGISTER #(.N(32)) wt_volume_reg (
    .clk(clk),
    .d(WT_SIZE * ifm_depth),
    .q(wt_volume)
  );

  REGISTER #(.N(32)) wt_len_reg (
    .clk(clk),
    .d(wt_volume * ofm_depth),
    .q(wt_len)
  );

  REGISTER #(.N(32)) ofm_size_reg (
    .clk(clk),
    .d(ofm_dim * ofm_dim),
    .q(ofm_size)
  );

  REGISTER #(.N(32)) ofm_len_reg (
    .clk(clk),
    .d(ofm_size * ofm_depth),
    .q(ofm_len)
  );

  wire xcel_write_request_fire = xcel_write_request_valid & xcel_write_request_ready;
  wire xcel_write_data_fire    = xcel_write_data_valid    & xcel_write_data_ready;
  wire xcel_read_request_fire  = xcel_read_request_valid  & xcel_read_request_ready;
  wire xcel_read_data_fire     = xcel_read_data_valid     & xcel_read_data_ready;

  localparam STATE_IDLE          = 0;
  localparam STATE_FETCH_OFM     = 1;
  localparam STATE_FETCH_WT      = 2;
  localparam STATE_FETCH_IFM     = 3;
  localparam STATE_COMPUTE       = 4;
  localparam STATE_WRITE_OFM_REQ = 5;
  localparam STATE_WRITE_OFM     = 6;
  localparam STATE_DONE          = 7;

  wire [2:0] state_value;
  reg  [2:0] state_next;

  REGISTER_R #(.N(3), .INIT(STATE_IDLE)) state_reg (
    .clk(clk),
    .rst(rst),
    .d(state_next),
    .q(state_value)
  );

  // input channel count: 0 -> ifm_depth - 1
  wire [31:0] ic_cnt_next, ic_cnt_value;
  wire ic_cnt_ce, ic_cnt_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ic_cnt_reg (
    .clk(clk),
    .rst(ic_cnt_rst),
    .d(ic_cnt_next),
    .q(ic_cnt_value),
    .ce(ic_cnt_ce)
  );

  // output channel count: 0 -> ofm_depth - 1
  wire [31:0] oc_cnt_next, oc_cnt_value;
  wire oc_cnt_ce, oc_cnt_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) oc_cnt_reg (
    .clk(clk),
    .rst(oc_cnt_rst),
    .d(oc_cnt_next),
    .q(oc_cnt_value),
    .ce(oc_cnt_ce)
  );

  // 0 --> WT_DIM - 1
  // keep track of the current sliding window in y-direction
  // (for fetching wt and ifm)
  wire [31:0] window_y_next, window_y_value;
  wire window_y_rst, window_y_ce;

  REGISTER_R_CE #(.N(32), .INIT(0)) window_y_reg (
    .clk(clk),
    .rst(window_y_rst),
    .d(window_y_next),
    .q(window_y_value),
    .ce(window_y_ce)
  );

  // 0 --> WT_DIM - 1
  // keep track of the current sliding window in x-direction
  // (for fetching wt and ifm)
  wire [31:0] window_x_next, window_x_value;
  wire window_x_rst, window_x_ce;

  REGISTER_R_CE #(.N(32), .INIT(0)) window_x_reg (
    .clk(clk),
    .rst(window_x_rst),
    .d(window_x_next),
    .q(window_x_value),
    .ce(window_x_ce)
  );

  // keep track of IFM index of the current sliding window
  // (for fetching ifm)
  wire [31:0] ifm_idx_next, ifm_idx_value;
  wire ifm_idx_ce, ifm_idx_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ifm_idx_reg (
    .clk(clk),
    .rst(ifm_idx_rst),
    .d(ifm_idx_next),
    .q(ifm_idx_value),
    .ce(ifm_idx_ce)
  );

  // 0 --> ofm_dim - 1
  // Keep track of OFM index of the current computing channel (y-direction)
  wire [31:0] ofm_y_next, ofm_y_value;
  wire ofm_y_rst, ofm_y_ce;

  REGISTER_R_CE #(.N(32), .INIT(0)) ofm_y_reg (
    .clk(clk),
    .rst(ofm_y_rst),
    .d(ofm_y_next),
    .q(ofm_y_value),
    .ce(ofm_y_ce)
  );

  // 0 --> ofm_dim - 1
  // Keep track of OFM index of the current computing channel (x-direction)
  wire [31:0] ofm_x_next, ofm_x_value;
  wire ofm_x_rst, ofm_x_ce;

  REGISTER_R_CE #(.N(32), .INIT(0)) ofm_x_reg (
    .clk(clk),
    .rst(ofm_x_rst),
    .d(ofm_x_next),
    .q(ofm_x_value),
    .ce(ofm_x_ce)
  );

  wire [31:0] ofm_offset0_next, ofm_offset0_value;
  wire ofm_offset0_ce, ofm_offset0_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ofm_offset0_reg (
    .clk(clk),
    .rst(ofm_offset0_rst),
    .d(ofm_offset0_next),
    .q(ofm_offset0_value),
    .ce(ofm_offset0_ce)
  );

  wire [31:0] ofm_offset1_next, ofm_offset1_value;
  wire ofm_offset1_ce, ofm_offset1_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ofm_offset1_reg (
    .clk(clk),
    .rst(ofm_offset1_rst),
    .d(ofm_offset1_next),
    .q(ofm_offset1_value),
    .ce(ofm_offset1_ce)
  );

  wire [31:0] ifm_offset0_next, ifm_offset0_value;
  wire ifm_offset0_ce, ifm_offset0_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ifm_offset0_reg (
    .clk(clk),
    .rst(ifm_offset0_rst),
    .d(ifm_offset0_next),
    .q(ifm_offset0_value),
    .ce(ifm_offset0_ce)
  );

  wire [31:0] ifm_offset1_next, ifm_offset1_value;
  wire ifm_offset1_ce, ifm_offset1_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) ifm_offset1_reg (
    .clk(clk),
    .rst(ifm_offset1_rst),
    .d(ifm_offset1_next),
    .q(ifm_offset1_value),
    .ce(ifm_offset1_ce)
  );

  wire [31:0] wt_offset0_next, wt_offset0_value;
  wire wt_offset0_ce, wt_offset0_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) wt_offset0_reg (
    .clk(clk),
    .rst(wt_offset0_rst),
    .d(wt_offset0_next),
    .q(wt_offset0_value),
    .ce(wt_offset0_ce)
  );

  wire [31:0] wt_offset1_next, wt_offset1_value;
  wire wt_offset1_ce, wt_offset1_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) wt_offset1_reg (
    .clk(clk),
    .rst(wt_offset1_rst),
    .d(wt_offset1_next),
    .q(wt_offset1_value),
    .ce(wt_offset1_ce)
  );

  wire [31:0] shift_cnt_next, shift_cnt_value;
  wire shift_cnt_ce, shift_cnt_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) shift_cnt_reg (
    .clk(clk),
    .rst(shift_cnt_rst),
    .d(shift_cnt_next),
    .q(shift_cnt_value),
    .ce(shift_cnt_ce)
  );

  wire [AXI_DWIDTH-1:0] ofm_data_next, ofm_data_value;
  wire ofm_data_ce, ofm_data_rst;

  REGISTER_R_CE #(.N(AXI_DWIDTH), .INIT(0)) ofm_data_reg (
    .clk(clk),
    .rst(ofm_data_rst),
    .d(ofm_data_next),
    .q(ofm_data_value),
    .ce(ofm_data_ce)
  );

  localparam DWIDTH = 8;

  // keep the state of the done signal
  // It needs to stay HIGH after the xcel is done
  // and restart to 0 once the xcel starts again
  wire xcel_done_next, xcel_done_value;
  wire xcel_done_ce, xcel_done_rst;
  REGISTER_R_CE #(.N(1), .INIT(0)) xcel_done_reg (
    .clk(clk),
    .rst(xcel_done_rst),
    .d(xcel_done_next),
    .q(xcel_done_value),
    .ce(xcel_done_ce)
  );

  wire [DWIDTH-1:0] wt_sr_next [0:WT_SIZE-1];
  wire [DWIDTH-1:0] wt_sr_value[0:WT_SIZE-1];
  wire wt_sr_ce [0:WT_SIZE-1];
  wire wt_sr_rst[0:WT_SIZE-1];

  genvar i;
  generate
    for (i = 0; i < WT_SIZE; i = i + 1) begin
      REGISTER_R_CE #(.N(DWIDTH), .INIT(0)) wt_sr_reg (
        .clk(clk),
        .rst(wt_sr_rst[i]),
        .d(wt_sr_next[i]),
        .q(wt_sr_value[i]),
        .ce(wt_sr_ce[i])
      );
    end
  endgenerate

  wire [DWIDTH-1:0] ifm_sr_next [0:WT_SIZE-1];
  wire [DWIDTH-1:0] ifm_sr_value[0:WT_SIZE-1];
  wire ifm_sr_ce [0:WT_SIZE-1];
  wire ifm_sr_rst[0:WT_SIZE-1];

  generate
    for (i = 0; i < WT_SIZE; i = i + 1) begin
      REGISTER_R_CE #(.N(DWIDTH), .INIT(0)) ifm_sr_reg (
        .clk(clk),
        .rst(ifm_sr_rst[i]),
        .d(ifm_sr_next[i]),
        .q(ifm_sr_value[i]),
        .ce(ifm_sr_ce[i])
      );
    end
  endgenerate

  wire [31:0] acc_next, acc_value;
  wire acc_ce, acc_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) acc_reg (
    .clk(clk),
    .rst(acc_rst),
    .d(acc_next),
    .q(acc_value),
    .ce(acc_ce)
  );

  wire [31:0] window_index = window_y_value * WT_DIM + window_x_value;

  wire [AXI_AWIDTH-1:0] wt_addr  = wt_ddr_addr +
                                   {(wt_offset0_value +
                                     wt_offset1_value +
                                     window_index) << 0};

  wire [AXI_AWIDTH-1:0] ifm_addr = ifm_ddr_addr +
                                   {(ifm_offset0_value +
                                     ifm_offset1_value +
                                     ofm_x_value       +
                                     ifm_idx_value) << 0};

  wire [AXI_AWIDTH-1:0] ofm_addr = ofm_ddr_addr +
                                   {(ofm_offset0_value +
                                     ofm_offset1_value  +
                                     ofm_x_value) << 2};

  // extract the correct byte from the read data based on the byte offset
  wire [DWIDTH-1:0] byte_wt = wt_addr[1:0] == 2'b00 ? xcel_read_data[7:0]   :
                              wt_addr[1:0] == 2'b01 ? xcel_read_data[15:8]  :
                              wt_addr[1:0] == 2'b10 ? xcel_read_data[23:16] :
                                                      xcel_read_data[31:24];

  wire [DWIDTH-1:0] byte_ifm = ifm_addr[1:0] == 2'b00 ? xcel_read_data[7:0]   :
                               ifm_addr[1:0] == 2'b01 ? xcel_read_data[15:8]  :
                               ifm_addr[1:0] == 2'b10 ? xcel_read_data[23:16] :
                                                        xcel_read_data[31:24];

  wire idle          = state_value == STATE_IDLE;
  wire fetch_ofm     = state_value == STATE_FETCH_OFM;
  wire fetch_wt      = state_value == STATE_FETCH_WT;
  wire fetch_ifm     = state_value == STATE_FETCH_IFM;
  wire compute       = state_value == STATE_COMPUTE;
  wire write_ofm_req = state_value == STATE_WRITE_OFM_REQ;
  wire write_ofm     = state_value == STATE_WRITE_OFM;
  wire done          = state_value == STATE_DONE;

  wire shift_done  = compute & (shift_cnt_value == WT_SIZE - 1);

  // conv2D is done when we write the last OFM result
  wire conv2D_done = write_ofm & xcel_write_data_fire &
                     (ofm_x_value == ofm_dim - 1) &
                     (ofm_y_value == ofm_dim - 1);

  // conv3D is done when we write the last OFM result
  // of the last ifm channel of the last ofm channel
  wire conv3D_done = conv2D_done &
                     (ic_cnt_value == ifm_depth - 1) &
                     (oc_cnt_value == ofm_depth - 1);

  always @(*) begin
    state_next = state_value;

    case (state_value)
      STATE_IDLE: begin
        if (xcel_start) begin
          // Skip the OFM fetch stage since we don't read from OFM
          // for the initial computation of the first output channel
          state_next = STATE_FETCH_WT;
        end
      end

      STATE_FETCH_OFM: begin
        if (xcel_read_data_fire)
          state_next = STATE_FETCH_WT;
      end

      // fetch WT_SIZE weight elements
      STATE_FETCH_WT: begin
        if (window_index == WT_SIZE - 1 && xcel_read_data_fire)
          state_next = STATE_FETCH_IFM;
      end

      // fetch WT_SIZE ifm elements (one WT_DIM x WT_DIM window of ifm)
      STATE_FETCH_IFM: begin
        if (window_index == WT_SIZE - 1 && xcel_read_data_fire)
          state_next = STATE_COMPUTE;
      end

      // one sliding-window computation
      STATE_COMPUTE: begin
        if (shift_cnt_value == WT_SIZE - 1)
          state_next = STATE_WRITE_OFM_REQ;
      end

      STATE_WRITE_OFM_REQ: begin
        // set up the write request of ofm result to DDR
        if (xcel_write_request_fire)
          state_next = STATE_WRITE_OFM;
      end

      STATE_WRITE_OFM: begin
        if (xcel_write_data_fire) begin
          if (conv3D_done)
            state_next = STATE_DONE;
          else begin
            // Don't fetch ofm if we are computing the first channel
            if (ic_cnt_value == 0 && (~conv2D_done))
              state_next = STATE_FETCH_IFM;
            // If we compute all the IFM channels, fetch the next set of weights
            else if (conv2D_done && ic_cnt_value == ifm_depth - 1)
              state_next = STATE_FETCH_WT;
            // Otherwise we fetch the old (partial) ofm from previous ifm channel to
            // accumulate with th next compute iteration of the current ifm channel
            else
              state_next = STATE_FETCH_OFM;
          end
        end
      end

      STATE_DONE: begin
        state_next = STATE_IDLE;
      end

    endcase
  end

  assign xcel_idle = idle;
  assign xcel_done = xcel_done_value & (~xcel_start);

  assign xcel_done_next = 1'b1;
  assign xcel_done_ce   = done;
  assign xcel_done_rst  = (idle & xcel_start) | rst;

  // update output channel counter when we finish conv2D of all IFM channel
  // (convolving with the current weight)
  assign oc_cnt_next = oc_cnt_value + 1;
  assign oc_cnt_ce   = (conv2D_done & ic_cnt_value == ifm_depth - 1);
  assign oc_cnt_rst  = idle;

  // ofm[ofm_offset0 + ofm_offset1 + ofm_x]
  //
  // current result of the sliding window
  assign ofm_x_next = ofm_x_value + 1;
  assign ofm_x_ce   = write_ofm & xcel_write_data_fire;
  assign ofm_x_rst  = (write_ofm & xcel_write_data_fire & (ofm_x_value == ofm_dim - 1)) | idle;

  // current result of the sliding window
  assign ofm_y_next = ofm_y_value + 1;
  assign ofm_y_ce   = write_ofm & xcel_write_data_fire  & (ofm_x_value == ofm_dim - 1);
  assign ofm_y_rst  = conv2D_done | idle | rst;

  // next OFM row
  assign ofm_offset1_next = ofm_offset1_value + ofm_dim;
  assign ofm_offset1_ce   = write_ofm & xcel_write_data_fire & (ofm_x_value == ofm_dim - 1);
  assign ofm_offset1_rst  = conv2D_done | idle;

  // next OFM channel
  assign ofm_offset0_next = ofm_offset0_value + ofm_size;
  assign ofm_offset0_ce   = (conv2D_done & ic_cnt_value == ifm_depth - 1);
  assign ofm_offset0_rst  = idle;

  // update input channel counter when we finish conv2D of the current channel
  assign ic_cnt_next = ic_cnt_value + 1;
  assign ic_cnt_ce   = conv2D_done;
  assign ic_cnt_rst  = (conv2D_done & ic_cnt_value == ifm_depth - 1) | idle;

  // ifm[ifm_offset0 + ifm_offset1 + ofm_x + ifm_idx]
  //
  // current sliding window indexing
  assign ifm_idx_next = (window_x_value == WT_DIM - 1) ? (ifm_idx_value + ifm_dim - WT_DIM + 1) :
                                                         (ifm_idx_value + 1);
  assign ifm_idx_ce   = fetch_ifm & xcel_read_data_fire;
  assign ifm_idx_rst  = (window_index == WT_SIZE - 1) & xcel_read_data_fire;

  // next IFM row
  assign ifm_offset1_next = ifm_offset1_value + ifm_dim;
  assign ifm_offset1_ce   = shift_done & (ofm_x_value == ofm_dim - 1);
  assign ifm_offset1_rst  = conv2D_done | idle;

  // next IFM channel
  assign ifm_offset0_next = ifm_offset0_value + ifm_size;
  assign ifm_offset0_ce   = conv2D_done;
  assign ifm_offset0_rst  = (conv2D_done & ic_cnt_value == ifm_depth - 1) | idle;

  // wt[wt_offset0 + wt_offset1 + window_y * WT_SIZE + window_x]
  // next WT channel
  assign wt_offset1_next = wt_offset1_value + WT_SIZE;
  assign wt_offset1_ce   = conv2D_done;
  assign wt_offset1_rst  = (conv2D_done & ic_cnt_value == ifm_depth - 1) | idle;

  // next WT (set of new WT channels)
  assign wt_offset0_next = wt_offset0_value + wt_volume;
  assign wt_offset0_ce   = (conv2D_done & ic_cnt_value == ifm_depth - 1);
  assign wt_offset0_rst  = idle;

  // current sliding window (x)
  assign window_x_next = window_x_value + 1;
  assign window_x_ce   = (fetch_wt | fetch_ifm) & xcel_read_data_fire;
  assign window_x_rst  = (window_x_value == WT_DIM - 1) & xcel_read_data_fire;

  // current sliding window (y)
  assign window_y_next = window_y_value + 1;
  assign window_y_ce   = (window_x_value == WT_DIM - 1) & (fetch_wt | fetch_ifm) & xcel_read_data_fire;
  assign window_y_rst  = (window_y_value == WT_DIM - 1) &
                         (window_x_value == WT_DIM - 1) &
                          xcel_read_data_fire;

  // Setup read request and read data
  // Read from OFM when we need to accumulate the past (partial) OFM result
  // with the current computing result
  // Read from WT at the beginning -- fetch all WT_SIZE weight elements
  // Read from IFM next -- fetch all WT_SIZE ifm elements of the current sliding
  // window that we are computing
  assign xcel_read_request_valid  = fetch_wt | fetch_ifm | fetch_ofm;
  assign xcel_read_addr           = fetch_ofm ? ofm_addr :
                                    fetch_wt  ? wt_addr  : ifm_addr;
  assign xcel_read_len            = 1 - 1; // no burst
  assign xcel_read_burst          = `BURST_INCR;
  assign xcel_read_size           = fetch_ofm ? 3'd2 : 3'd0; // 4 bytes if fetching ofm, otherwise 1 byte
  assign xcel_read_data_ready     = fetch_wt | fetch_ifm | fetch_ofm;

  // Setup write request and write data
  // Write a single OFM element back to DDR whenever we finish one sliding-window
  // computation
  assign xcel_write_request_valid = write_ofm_req;
  assign xcel_write_addr          = ofm_addr;
  assign xcel_write_len           = 1 - 1; // no burst
  assign xcel_write_burst         = `BURST_INCR;
  assign xcel_write_size          = 3'd2; // 4 bytes;
  assign xcel_write_data_valid    = write_ofm;
  assign xcel_write_data          = ofm_data_value + {$signed(acc_value) >>> 9};

  // Shift registers to hold weight data
  generate
    for (i = 0; i < WT_SIZE; i = i + 1) begin
      if (i == WT_SIZE - 1)
        assign wt_sr_next[i] = fetch_wt ? byte_wt : wt_sr_value[0];
      else
        assign wt_sr_next[i] = wt_sr_value[i + 1];

      assign wt_sr_ce[i]  = (fetch_wt & xcel_read_data_fire) | compute;
      assign wt_sr_rst[i] = idle;
    end
  endgenerate

  // Shift registers to ifm data
  generate
    for (i = 0; i < WT_SIZE; i = i + 1) begin
      if (i == WT_SIZE - 1)
        assign ifm_sr_next[i] = fetch_ifm ? byte_ifm : ifm_sr_value[0];
      else
        assign ifm_sr_next[i] = ifm_sr_value[i + 1];

      assign ifm_sr_ce[i]  = (fetch_ifm & xcel_read_data_fire) | compute;
      assign ifm_sr_rst[i] = idle;
    end
  endgenerate

  // Reg the read OFM data from the DDR
  assign ofm_data_next = xcel_read_data;
  assign ofm_data_ce   = fetch_ofm & xcel_read_data_fire;
  assign ofm_data_rst  = (conv2D_done & ic_cnt_value == ifm_depth - 1) | idle;

  // Multiply-accumulator to compute one sliding-window computation of an OFM element
  //        wt[0] <-- wt[1] <-- wt[2] <-- ... <-- wt[WT_SIZE-1]
  //        |                                        ^
  //        |________________________________________|
  //        |
  // acc = +*________________________________________
  //        |                                        |
  //        |                                        v
  //        ifm[0] <-- ifm[1] <-- ifm[2] <-- ... <-- ifm[WT_SIZE-1]

  wire signed [15:0] ifm_s0 = $signed(ifm_sr_value[0]);
  wire signed [15:0] wt_s0  = $signed(wt_sr_value[0]);
  (* use_dsp48 = "yes" *) wire signed [15:0] tmp  = ifm_s0 * wt_s0;

  assign acc_next = acc_value + {{16{tmp[15]}}, tmp[15:0]};
  assign acc_ce   = compute;
  assign acc_rst  = fetch_ifm | idle;

  // shift count. Count WT_SIZE cycles to finish one sliding-window computation
  assign shift_cnt_next = shift_cnt_value + 1;
  assign shift_cnt_ce   = compute;
  assign shift_cnt_rst  = shift_done | idle;

endmodule
