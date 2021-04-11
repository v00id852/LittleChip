`include "axi_consts.vh"

module dma_controller #(
  parameter AXI_AWIDTH  = 32,
  parameter AXI_DWIDTH  = 32,
  parameter DMEM_AWIDTH = 14,
  parameter DMEM_DWIDTH = 32
) (
  input clk,
  input resetn,

  output                  dma_read_request_valid,
  input                   dma_read_request_ready,
  output [AXI_AWIDTH-1:0] dma_read_addr,
  output [31:0]           dma_read_len,
  output [2:0]            dma_read_size,
  output [1:0]            dma_read_burst,
  input  [AXI_DWIDTH-1:0] dma_read_data,
  input                   dma_read_data_valid,
  output                  dma_read_data_ready,

  output                  dma_write_request_valid,
  input                   dma_write_request_ready,
  output [AXI_AWIDTH-1:0] dma_write_addr,
  output [31:0]           dma_write_len,
  output [2:0]            dma_write_size,
  output [1:0]            dma_write_burst,
  output [AXI_DWIDTH-1:0] dma_write_data,
  output                  dma_write_data_valid,
  input                   dma_write_data_ready,
 
  input  dma_start,
  output dma_done,
  output dma_idle,
  input  dma_dir, // 1: DMem -> DDR, 0: DDR -> DMem
  input [31:0] dma_src_addr,
  input [31:0] dma_dst_addr,
  input [31:0] dma_len,

  output [DMEM_AWIDTH-1:0]   dmem_addr,
  output [DMEM_DWIDTH-1:0]   dmem_din,
  input  [DMEM_DWIDTH-1:0]   dmem_dout,
  output [DMEM_DWIDTH/8-1:0] dmem_wbe,
  output                     dmem_en
);

  wire dma_write_request_fire = dma_write_request_valid & dma_write_request_ready;
  wire dma_write_data_fire    = dma_write_data_valid & dma_write_data_ready;
  wire dma_read_request_fire  = dma_read_request_valid & dma_read_request_ready;
  wire dma_read_data_fire     = dma_read_data_valid & dma_read_data_ready;

  localparam STATE_IDLE      = 3'b000;
  localparam STATE_WRITE_DDR = 3'b001;
  localparam STATE_WRITE_DDR_DELAY = 3'b010;
  localparam STATE_READ_DDR  = 3'b011;
  localparam STATE_DONE      = 3'b100;

  wire [2:0] state_value;
  reg  [2:0] state_next;
  REGISTER_R #(.N(3), .INIT(STATE_IDLE)) state_reg (
    .clk(clk),
    .rst(~resetn),
    .d(state_next),
    .q(state_value)
  );

  wire [31:0] write_cnt_next, write_cnt_value;
  wire write_cnt_ce, write_cnt_rst;
  REGISTER_R_CE #(.N(32), .INIT(0)) write_cnt_reg (
    .clk(clk),
    .rst(write_cnt_rst),
    .d(write_cnt_next),
    .q(write_cnt_value),
    .ce(write_cnt_ce)
  );

  wire [31:0] read_cnt_next, read_cnt_value;
  wire read_cnt_ce, read_cnt_rst;
  REGISTER_R_CE #(.N(32), .INIT(0)) read_cnt_reg (
    .clk(clk),
    .rst(read_cnt_rst),
    .d(read_cnt_next),
    .q(read_cnt_value),
    .ce(read_cnt_ce)
  );

  wire dma_done_next, dma_done_value;
  wire dma_done_ce, dma_done_rst;
  REGISTER_R_CE #(.N(1), .INIT(0)) dma_done_reg (
    .clk(clk),
    .rst(dma_done_rst),
    .d(dma_done_next),
    .q(dma_done_value),
    .ce(dma_done_ce)
  );

  always @(*) begin
    state_next = state_value;
    case (state_value)
    STATE_IDLE: begin
      if (dma_start) begin
        if (dma_dir == 0)
          state_next = STATE_READ_DDR;
        else
          state_next = STATE_WRITE_DDR;
      end
    end

    STATE_READ_DDR: begin
      if (read_cnt_value == dma_len)
        state_next = STATE_DONE;
    end

    STATE_WRITE_DDR: begin
      // setup reading from DMem, since reading from synchronous memory takes one cycle
      if (dma_write_request_fire)
        state_next = STATE_WRITE_DDR_DELAY;
    end

    STATE_WRITE_DDR_DELAY: begin
      if (write_cnt_value == dma_len)
        state_next = STATE_DONE;
    end

    STATE_DONE: begin
      state_next = STATE_IDLE;
    end

    endcase
  end

  assign dma_idle = state_value == STATE_IDLE;
  assign dma_done = dma_done_value & (~dma_start);

  assign dma_done_next = 1'b1;
  assign dma_done_ce   = state_value == STATE_DONE;
  assign dma_done_rst  = ((state_value == STATE_IDLE) & dma_start) | (~resetn);

  assign write_cnt_next = write_cnt_value + 1;
  assign write_cnt_ce   = (state_value == STATE_WRITE_DDR && dma_write_request_fire) | dma_write_data_fire;
  assign write_cnt_rst  = (state_value == STATE_IDLE) | (~resetn);

  assign read_cnt_next = read_cnt_value + 1;
  assign read_cnt_ce   = dma_read_data_fire;
  assign read_cnt_rst  = (state_value == STATE_IDLE) | (~resetn);

  assign dma_write_request_valid = state_value == STATE_WRITE_DDR;
  assign dma_write_addr          = dma_dst_addr;
  assign dma_write_len           = dma_len - 1;
  assign dma_write_burst         = `BURST_INCR;
  assign dma_write_size          = 3'd2; // 2^2 bytes
  assign dma_write_data_valid    = state_value == STATE_WRITE_DDR_DELAY;
  assign dma_write_data          = dmem_dout;

  assign dma_read_request_valid = state_value == STATE_READ_DDR;
  assign dma_read_addr          = dma_src_addr;
  assign dma_read_len           = dma_len - 1;
  assign dma_read_burst         = `BURST_INCR;
  assign dma_read_size          = 3'd2; // 2^2 bytes
  assign dma_read_data_ready    = state_value == STATE_READ_DDR;

  assign dmem_addr = (state_value == STATE_READ_DDR) ? (dma_dst_addr + read_cnt_value) :
                                                       (dma_src_addr + write_cnt_value);
  assign dmem_wbe  = ((state_value == STATE_READ_DDR) & dma_read_data_fire) ? 4'b1111 : 4'b0;
  assign dmem_din  = dma_read_data;
  assign dmem_en   = (state_value == STATE_WRITE_DDR) |
                     dma_write_data_fire |
                     dma_read_data_fire;
endmodule
