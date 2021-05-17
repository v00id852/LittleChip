// Disc: Generate control signals decided by opcode
`include "Opcode.vh"
module CONTROL (
  input [6:0] opcode,
  output reg_write,
  output [1:0] alu_src,
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

  assign alu_op[0] = (opcode == `OPC_ARI_ITYPE || opcode == `OPC_ARI_RTYPE) ? 1'b0 : 
                     (opcode == `OPC_BRANCH);
  assign alu_op[1] = (opcode == `OPC_ARI_ITYPE) || (opcode == `OPC_ARI_RTYPE);

  always @(*) begin
    if (opcode == `OPC_LOAD || opcode == `OPC_STORE) begin
      alu_src = 2'b00;
    end else begin
      // FIXME
      alu_src = 2'b01;
    end
  end

endmodule
