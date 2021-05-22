`include "Opcode.vh"

module MEM_DATA_GEN #(
  parameter DATA_WIDTH = 32
) (
  input [DATA_WIDTH - 1:0] data_in,
  input [2:0] inst_func_in,
  input [1:0] byte_addr_in,
  output [DATA_WIDTH - 1:0] data_out,
  output [DATA_WIDTH / 8 - 1:0] wea_out
);

  reg [5:0] bit_index;
  wire [2:0] mask_index;

  always @(*) begin
    bit_index = byte_addr_in << 3;
    if (inst_func_in == `FNC_SH && (byte_addr_in == 2'd3 || byte_addr_in == 2'd1)) begin
      bit_index = (byte_addr_in - 1) << 3;
    end
  end
  
  assign mask_index = ((byte_addr_in == 2'd3 || byte_addr_in == 2'd1) && inst_func_in == `FNC_SH) 
                      ? byte_addr_in - 1 : byte_addr_in;
  assign data_out = data_in << bit_index;
  assign wea_out = (inst_func_in == `FNC_SW) ? 4'b1111 :
                   (inst_func_in == `FNC_SH) ? 4'b0011 << mask_index :
                   4'b1 << mask_index;
                   
endmodule