`include "Opcode.vh"

module MEM_DATA_MASK #(
  parameter DATA_WIDTH = 32
) (
  input [DATA_WIDTH - 1:0] data_in,
  input [2:0] inst_func_in,
  input [1:0] byte_addr_in,
  output reg [DATA_WIDTH - 1:0] data_out
);

  wire [5:0] offset = (byte_addr_in[1] << 4) | (byte_addr_in[0] << 3);
  wire [DATA_WIDTH - 1:0] data_shift = $signed(data_in) >>> offset; 

  always @(*) begin
    case (inst_func_in)
      `FNC_LW:  data_out = data_in;
      `FNC_LB:  data_out = {{(DATA_WIDTH - 8){data_shift[7]}}, data_shift[7:0]};
      `FNC_LH:  data_out = {{(DATA_WIDTH - 16){data_shift[15]}}, data_shift[15:0]};
      `FNC_LHU: data_out = {{(DATA_WIDTH - 16){1'b0}}, data_shift[15:0]};
      `FNC_LBU: data_out = {{(DATA_WIDTH - 8){1'b0}}, data_shift[7:0]};
      default:  data_out = data_in;
    endcase
  end

endmodule
