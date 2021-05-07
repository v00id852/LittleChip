
module uart_transmitter #(
  parameter CLOCK_FREQ = 125_000_000,
  parameter BAUD_RATE = 115_200
) (
  input clk,
  input rst,

  input [7:0] data_in,
  input data_in_valid,
  output data_in_ready,

  output serial_out
);

  localparam integer SYMBOL_EDGE_TIME = CLOCK_FREQ / BAUD_RATE;
  localparam CLOCK_COUNTER_WIDTH      = $clog2(SYMBOL_EDGE_TIME);

  wire [9:0] tx_shift_value;
  wire [9:0] tx_shift_next;
  wire tx_shift_ce;

  REGISTER_CE #(.N(10)) tx_shift (
    .q(tx_shift_value),
    .d(tx_shift_next),
    .ce(tx_shift_ce),
    .clk(clk)
  );

  wire [3:0] bit_counter_value;
  wire [3:0] bit_counter_next;
  wire bit_counter_ce, bit_counter_rst;

  REGISTER_R_CE #(.N(4), .INIT(0)) bit_counter_reg (
    .q(bit_counter_value),
    .d(bit_counter_next),
    .ce(bit_counter_ce),
    .rst(bit_counter_rst),
    .clk(clk)
  );

  wire [CLOCK_COUNTER_WIDTH-1:0] clock_counter_value;
  wire [CLOCK_COUNTER_WIDTH-1:0] clock_counter_next;
  wire clock_counter_ce, clock_counter_rst;

  // Keep track of sample time and symbol edge time
  REGISTER_R_CE #(.N(CLOCK_COUNTER_WIDTH), .INIT(0)) clock_counter (
    .q(clock_counter_value),
    .d(clock_counter_next),
    .ce(clock_counter_ce),
    .rst(clock_counter_rst),
    .clk(clk)
  );

  wire data_in_fire   = data_in_valid & data_in_ready;
  wire symbol_edge = (clock_counter_value == SYMBOL_EDGE_TIME - 1);

  assign clock_counter_next = clock_counter_value + 1;
  assign clock_counter_ce = 1'b1;
  assign clock_counter_rst = rst | symbol_edge | data_in_fire;

  assign bit_counter_next = (bit_counter_value == 4'd9) ? 4'd9 : bit_counter_value + 1;
  assign bit_counter_ce = symbol_edge; 
  assign bit_counter_rst = rst | data_in_fire;


  wire uart_status_value;
  reg uart_status_next;

  localparam STATUS_IDLE = 1'b0;
  localparam STATUS_SEND = 1'b1; 

  REGISTER_R #(.N(1)) uart_status (
    .clk(clk),
    .rst(rst),
    .d(uart_status_next),
    .q(uart_status_value)
  );

  always @(*) begin
    uart_status_next = uart_status_value;
    case (uart_status_value)
      STATUS_IDLE: begin
        if (data_in_fire) begin
          uart_status_next = STATUS_SEND;
        end
      end
      STATUS_SEND: begin
        if (bit_counter_value == 4'd9 && symbol_edge) begin
          uart_status_next = STATUS_IDLE;
        end 
      end
    endcase
  end

  assign serial_out = (uart_status_value == STATUS_IDLE) ? 1'b1 : tx_shift_value[bit_counter_value];
  assign data_in_ready = (uart_status_value == STATUS_IDLE) ? 1'b1 : 1'b0;


  assign tx_shift_next = {1'b1, data_in, 1'b0};
  assign tx_shift_ce = data_in_fire;
endmodule
