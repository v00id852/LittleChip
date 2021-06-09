`include "Opcode.vh"

module MEM_DATA_GEN #(
  parameter DATA_WIDTH = 32
) (
  input [DATA_WIDTH - 1:0] data_in,
  input [2:0] inst_func_in,
  input [1:0] byte_addr_in,
  output [DATA_WIDTH - 1:0] data_out,
  output reg [DATA_WIDTH / 8 - 1:0] wea_out
);

  wire [5:0] bit_index;
  reg [2:0] mask_index;

  always @(*) begin
    case (inst_func_in)
      `FNC_SH: begin
        case (byte_addr_in)
          2'd0: mask_index = 0;
          2'd1: mask_index = 0;
          2'd2: mask_index = 2;
          2'd3: mask_index = 2;
          default: mask_index = 0;
        endcase
      end
      default: begin
        mask_index = byte_addr_in;
      end
    endcase
  end

  assign bit_index = mask_index << 3;

  // always @(*) begin
  //   case (inst_func_in)
  //     `FNC_SH: begin
  //       case (byte_addr_in)
  //         2'd0: bit_index = 0;
  //         2'd1: bit_index = 0;
  //         2'd2: bit_index = 2 << 3;
  //         2'd3: bit_index = 2 << 3;
  //       endcase
  //     end
  //     default: bit_index = byte_addr_in << 3;
  //   endcase
  // end

  always @(*) begin
    case (inst_func_in)
      `FNC_SW: wea_out = 4'b1111;
      `FNC_SH: wea_out = 4'b0011 << mask_index;
      default: wea_out = 4'b0001 << mask_index;
    endcase
  end

  assign data_out = data_in << bit_index;
                   
endmodule