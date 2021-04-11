
// Simple memory model for RTL simulation
// Convert AXI interface to BRAM interface and vice versa
// TODO: add delay as parameter
module mem_model #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter MEM_AWIDTH = 14
) (
  input clk,
  input rst,

  input                   read_request_valid,
  output                  read_request_ready,
  input  [AXI_AWIDTH-1:0] read_request_addr,
  input  [31:0]           read_len,
  input  [2:0]            read_size,
  output [AXI_DWIDTH-1:0] read_data,
  output                  read_data_valid,
  input                   read_data_ready,

  input                   write_request_valid,
  output                  write_request_ready,
  input [AXI_AWIDTH-1:0]  write_request_addr,
  input [31:0]            write_len,
  input [2:0]             write_size,
  input [AXI_DWIDTH-1:0]  write_data,
  input                   write_data_valid,
  output                  write_data_ready
);

  wire read_request_fire  = read_request_valid  & read_request_ready;
  wire read_data_fire     = read_data_valid     & read_data_ready;
  wire write_request_fire = write_request_valid & write_request_ready;
  wire write_data_fire    = write_data_valid    & write_data_ready;

  wire [MEM_AWIDTH-1:0] mem_addr0, mem_addr1;
  wire [AXI_DWIDTH-1:0] mem_dout0, mem_din1;
  wire                  mem_en0, mem_en1, mem_we1;

  SYNC_RAM_DP #(
    .AWIDTH(MEM_AWIDTH),
    .DWIDTH(AXI_DWIDTH)
  ) buffer (
    .clk(clk),

    // for read
    .addr0(mem_addr0),
    .d0(),
    .q0(mem_dout0),
    .we0(1'b0),
    .en0(mem_en0),

    // for write
    .addr1(mem_addr1),
    .d1(mem_din1),
    .q1(),
    .we1(mem_we1),
    .en1(mem_en1)
  );

  localparam STATE_R_IDLE      = 0;
  localparam STATE_R_RUN       = 1;
  localparam STATE_R_RUN_DELAY = 2;
  localparam STATE_R_DONE      = 3;

  localparam STATE_W_IDLE = 0;
  localparam STATE_W_RUN  = 1;
  localparam STATE_W_DONE = 2;

  wire [1:0] state_r_value, state_w_value;
  reg  [1:0] state_r_next,  state_w_next;

  REGISTER_R #(.N(2), .INIT(STATE_R_IDLE)) state_r_reg (
    .clk(clk),
    .rst(rst),
    .d(state_r_next),
    .q(state_r_value)
  );

  REGISTER_R #(.N(2), .INIT(STATE_R_IDLE)) state_w_reg (
    .clk(clk),
    .rst(rst),
    .d(state_w_next),
    .q(state_w_value)
  );

  wire [31:0] read_cnt_value, read_cnt_next;
  wire read_cnt_ce, read_cnt_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) read_cnt_reg (
    .clk(clk),
    .rst(read_cnt_rst),
    .d(read_cnt_next),
    .q(read_cnt_value),
    .ce(read_cnt_ce)
  );

  wire [31:0] write_cnt_value, write_cnt_next;
  wire write_cnt_ce, write_cnt_rst;

  REGISTER_R_CE #(.N(32), .INIT(0)) write_cnt_reg (
    .clk(clk),
    .rst(write_cnt_rst),
    .d(write_cnt_next),
    .q(write_cnt_value),
    .ce(write_cnt_ce)
  );

  wire [31:0] read_len_value;

  REGISTER_CE #(.N(32)) read_len_reg (
    .clk(clk),
    .d(read_len),
    .q(read_len_value),
    .ce(read_request_fire)
  );

  wire [31:0] write_len_value;

  REGISTER_CE #(.N(32)) write_len_reg (
    .clk(clk),
    .d(write_len),
    .q(write_len_value),
    .ce(write_request_fire)
  );

  wire [31:0] read_request_addr_value;

  REGISTER_CE #(.N(32)) read_addr_reg (
    .clk(clk),
    .d(read_request_addr),
    .q(read_request_addr_value),
    .ce(read_request_fire)
  );

  wire [31:0] write_request_addr_value;

  REGISTER_CE #(.N(32)) write_addr_reg (
    .clk(clk),
    .d(write_request_addr),
    .q(write_request_addr_value),
    .ce(write_request_fire)
  );

  always @(*) begin
    state_r_next = state_r_value;
    case (state_r_value)
      STATE_R_IDLE: begin
        if (read_request_fire)
          state_r_next = STATE_R_RUN;
      end

      STATE_R_RUN: begin
        state_r_next = STATE_R_RUN_DELAY;
      end

      STATE_R_RUN_DELAY: begin
        if (read_cnt_value == read_len_value + 1)
          state_r_next = STATE_R_DONE;
      end

      STATE_R_DONE: begin
        state_r_next = STATE_R_IDLE;
      end
    endcase
  end

  always @(*) begin
    state_w_next = state_w_value;
    case (state_w_value)
      STATE_W_IDLE: begin
        if (write_request_fire)
          state_w_next = STATE_W_RUN;
      end

      STATE_W_RUN: begin
        if (write_cnt_value == write_len_value + 1)
          state_w_next = STATE_W_DONE;
      end

      STATE_W_DONE: begin
        state_w_next = STATE_W_IDLE;
      end
    endcase
  end

  assign read_request_ready  = (state_r_value == STATE_R_IDLE);
  assign write_request_ready = (state_w_value == STATE_R_IDLE);

  assign read_cnt_next = read_cnt_value + 1;
  assign read_cnt_ce   = (state_r_value == STATE_R_RUN)  | read_data_fire;
  assign read_cnt_rst  = (state_r_value == STATE_R_IDLE) | rst;

  assign write_cnt_next = write_cnt_value + 1;
  assign write_cnt_ce   = (state_w_value == STATE_W_RUN) & write_data_fire;
  assign write_cnt_rst  = (state_w_value == STATE_W_IDLE) | rst;

  assign mem_addr0 = (read_request_addr_value + {read_cnt_value << read_size}) >> 2;
  assign mem_en0   = (state_r_value == STATE_R_RUN) | read_data_fire;

  assign mem_addr1 = (write_request_addr_value + {write_cnt_value << write_size}) >> 2;
  assign mem_din1  = write_data;
  assign mem_we1   = write_data_fire;
  assign mem_en1   = (state_w_value == STATE_W_RUN);

  assign read_data        = mem_dout0;
  assign read_data_valid  = (state_r_value == STATE_R_RUN_DELAY);
  assign write_data_ready = (state_w_value == STATE_W_RUN);

endmodule
