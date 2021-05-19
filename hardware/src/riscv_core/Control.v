// Disc: Generate control signals decided by opcode
`include "Opcode.vh"
module CONTROL (
  input [6:0] opcode,
  output reg_write,
  output [1:0] alu_src_a,
  output [1:0] alu_src_b,
  output mem_write,
  output mem_read,
  output mem_to_reg,
  output pc_src,
  output [1:0] alu_op
);

  // expecpt B and S
  assign reg_write = (opcode != `OPC_BRANCH) && (opcode != `OPC_STORE);
  // from register (0) or immediate (1)
  assign mem_write = opcode == `OPC_STORE;
  assign mem_read = opcode == `OPC_LOAD;

  assign mem_to_reg = opcode == `OPC_LOAD;
  assign pc_src = opcode == `OPC_BRANCH;

  reg [1:0] alu_op;

  always @(*) begin
    case (opcode)
      `OPC_ARI_ITYPE: alu_op = 2'b11;
      `OPC_ARI_RTYPE: alu_op = 2'b10;
      `OPC_BRANCH: alu_op = 2'b01;
      default: alu_op = 2'b00;
    endcase
  end
  
  reg [1:0] alu_src_a, alu_src_b;

  always @(*) begin
    if (opcode == `OPC_LUI)
      alu_src_a = 2'b01;
    else
      alu_src_a = 2'b00;
  end

  always @(*) begin
    if (opcode == `OPC_LOAD  || 
        opcode == `OPC_STORE || 
        opcode == `OPC_ARI_ITYPE ||
        opcode == `OPC_LUI) begin
      // Immediate
      alu_src_b = 2'b01;
    end else begin     
      // FIXME
      alu_src_b = 2'b00;
    end
  end

endmodule
