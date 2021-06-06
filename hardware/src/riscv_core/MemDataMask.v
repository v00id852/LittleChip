`include "Opcode.vh"

module MEM_DATA_MASK #(
  parameter DATA_WIDTH = 32
) (
  input [DATA_WIDTH - 1:0] data_in,
  input [2:0] inst_func_in,
  input [1:0] byte_addr_in,
  output reg [DATA_WIDTH - 1:0] data_out
);

  reg [5:0] bit_index;

  always @(*) begin
    case (inst_func_in)
      `FNC_LH: begin
        case (byte_addr_in)
          2'b00: bit_index = 0;
          2'b01: bit_index = 0;
          2'b10: bit_index = 2 << 3;
          2'b11: bit_index = 2 << 3;
        endcase
      end
      `FNC_LHU: begin
        case (byte_addr_in)
          2'b00: bit_index = 0;
          2'b01: bit_index = 0;
          2'b10: bit_index = 2 << 3;
          2'b11: bit_index = 2 << 3;
        endcase 
      end
      default: bit_index = byte_addr_in << 3;
    endcase
  end

  always @(*) begin
    case (inst_func_in)
      `FNC_LW:  data_out = data_in;
      `FNC_LB:  data_out = {{24{data_in[bit_index+8-1]}}, data_in[bit_index+:8]};
      `FNC_LH:  data_out = {{16{data_in[bit_index+16-1]}}, data_in[bit_index+:16]};
      `FNC_LHU: data_out = {16'b0, data_in[bit_index+:16]};
      `FNC_LBU: data_out = {16'b0, data_in[bit_index+:8]};
      default:  data_out = data_in;
    endcase
  end

endmodule
