`include "axi_consts.vh"

module axi_mm_read #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter AXI_MAX_BURST_LEN = 256
) (
  input clk,
  input resetn, // active-low reset

  // Read request address channel
  output [3:0]            arid,
  (* mark_debug = "True" *) output [AXI_AWIDTH-1:0] araddr,
  (* mark_debug = "True" *) output                  arvalid,
  (* mark_debug = "True" *) input                   arready,
  (* mark_debug = "True" *) output [7:0]            arlen,
  (* mark_debug = "True" *) output [2:0]            arsize,
  (* mark_debug = "True" *) output [1:0]            arburst,
  // lock, cache, prot, qos, region, user (unused)

  // Read response data channel
  input  [3:0]            rid,
  (* mark_debug = "True" *) input  [AXI_DWIDTH-1:0] rdata,
  (* mark_debug = "True" *) input                   rvalid,
  (* mark_debug = "True" *) output                  rready,
  (* mark_debug = "True" *) input                   rlast,
  input  [1:0]            rresp,
  // user (unused)

  // Core (client) read interface
  input                   core_read_request_valid,
  output                  core_read_request_ready,
  input  [AXI_AWIDTH-1:0] core_read_addr,
  input  [31:0]           core_read_len,
  input  [2:0]            core_read_size,
  input  [1:0]            core_read_burst,
  output [AXI_DWIDTH-1:0] core_read_data,
  output                  core_read_data_valid,
  input                   core_read_data_ready
);

  // number of data transfers (beats) = len + 1
  // number of bytes in transfer = 2^size

  wire ar_fire = arvalid & arready;
  wire dr_fire = rvalid  & rready;

  wire core_read_request_fire  = core_read_request_valid & core_read_request_ready;

  localparam STATE_AR_IDLE = 2'b00;
  localparam STATE_AR_RUN  = 2'b01;
  localparam STATE_AR_DONE = 2'b10;

  localparam STATE_DR_IDLE = 2'b00;
  localparam STATE_DR_RUN  = 2'b01;
  localparam STATE_DR_DONE = 2'b10;

  wire [1:0] state_ar_value;
  reg  [1:0] state_ar_next;
  wire [1:0] state_dr_value;
  reg  [1:0] state_dr_next;

  REGISTER_R #(.N(2), .INIT(STATE_AR_IDLE)) state_ar_reg (
    .clk(clk),
    .rst(~resetn),
    .d(state_ar_next),
    .q(state_ar_value)
  );

  REGISTER_R #(.N(2), .INIT(STATE_DR_IDLE)) state_dr_reg (
    .clk(clk),
    .rst(~resetn),
    .d(state_dr_next),
    .q(state_dr_value)
  );

  wire [AXI_AWIDTH-1:0] raddr_next, raddr_value;
  wire raddr_ce;
  REGISTER_R_CE #(.N(AXI_AWIDTH), .INIT(0)) raddr_reg (
    .clk(clk),
    .rst(~resetn),
    .d(raddr_next),
    .q(raddr_value),
    .ce(raddr_ce)
  );

  wire [31:0] rlen_next, rlen_value;
  wire rlen_ce;
  REGISTER_R_CE #(.N(32), .INIT(0)) rlen_reg (
    .clk(clk),
    .rst(~resetn),
    .d(rlen_next),
    .q(rlen_value),
    .ce(rlen_ce)
  );

  wire [2:0] rsize_next, rsize_value;
  wire rsize_ce;
  REGISTER_R_CE #(.N(3), .INIT(0)) rsize_reg (
    .clk(clk),
    .rst(~resetn),
    .d(rsize_next),
    .q(rsize_value),
    .ce(rsize_ce)
  );

  wire [1:0] rburst_next, rburst_value;
  wire rburst_ce;
  REGISTER_R_CE #(.N(2), .INIT(0)) rburst_reg (
    .clk(clk),
    .rst(~resetn),
    .d(rburst_next),
    .q(rburst_value),
    .ce(rburst_ce)
  );

  wire rburst_resume_next, rburst_resume_value;
  wire rburst_resume_ce, rburst_resume_rst;

  REGISTER_R_CE #(.N(1), .INIT(0)) rburst_resume_reg (
    .clk(clk),
    .rst(rburst_resume_rst),
    .d(rburst_resume_next),
    .q(rburst_resume_value),
    .ce(rburst_resume_ce)
  );

  always @(*) begin
    state_ar_next = state_ar_value;
    case (state_ar_value)
      STATE_AR_IDLE: begin
        if (core_read_request_fire || rburst_resume_value)
          state_ar_next = STATE_AR_RUN;
      end

      STATE_AR_RUN: begin
        if (ar_fire) begin
          state_ar_next = STATE_AR_DONE;
        end
      end

      STATE_AR_DONE: begin
        state_ar_next = STATE_AR_IDLE;
      end

    endcase
  end

  always @(*) begin
    state_dr_next = state_dr_value;
    case (state_dr_value)
      STATE_DR_IDLE: begin
        if (ar_fire)
          state_dr_next = STATE_DR_RUN;
      end

      STATE_DR_RUN: begin
        if (dr_fire && rlast) begin
          state_dr_next = STATE_DR_DONE;
        end
      end

      STATE_DR_DONE: begin
        state_dr_next = STATE_DR_IDLE;
      end

    endcase
  end

  wire full_rburst = rlen_value > AXI_MAX_BURST_LEN - 1;

  assign rsize_next = core_read_size;
  assign rsize_ce   = core_read_request_fire;

  assign rburst_next = core_read_burst;
  assign rburst_ce   = core_read_request_fire;

  assign raddr_next = core_read_request_fire ? core_read_addr :
                                               raddr_value + (AXI_MAX_BURST_LEN << 2);
  assign raddr_ce   = core_read_request_fire | (dr_fire & rlast);

  assign rlen_next = core_read_request_fire ? core_read_len :
                                              rlen_value - AXI_MAX_BURST_LEN;
  assign rlen_ce   = core_read_request_fire | (dr_fire & rlast);

  assign rburst_resume_next = full_rburst ? 1 : 0;
  assign rburst_resume_ce   = dr_fire & rlast;
  assign rburst_resume_rst  = (state_dr_value == STATE_DR_IDLE) | (~resetn);

  assign arvalid = (state_ar_value == STATE_AR_RUN);
  assign rready  = (state_dr_value == STATE_DR_RUN) & core_read_data_ready;
  assign araddr  = raddr_value;
  assign arlen   = full_rburst ? AXI_MAX_BURST_LEN - 1 : rlen_value;
  assign arsize  = rsize_value;
  assign arburst = rburst_value;

  assign core_read_request_ready = (state_dr_value == STATE_DR_IDLE) &
                                   (~rburst_resume_value);
  assign core_read_data       = rdata;
  assign core_read_data_valid = (state_dr_value == STATE_DR_RUN) & rvalid;

  // Keep it simple: use ID 0 for now
  assign arid = 0;

  // Keep it simple: ignore bid and rid for now

endmodule
