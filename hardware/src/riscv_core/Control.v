// Disc: Generate control signals decided by opcode
`include "Opcode.vh"
module CONTROL #(
  parameter INST_WIDTH = 32
) (
  input [INST_WIDTH - 1:0] inst,
  output reg_write,
  output mem_write,
  output mem_read,
  output [1:0] mem_to_reg,
  output utype_src,
  output jtype_src,
  output jalr_src,
  output branch,
  output jump,
  output [1:0] alu_op,
  output [1:0] alu_src_a,
  output [1:0] alu_src_b,
  output csr_we,
  output csr_rd
);

  wire [6:0] opcode;
  wire [4:0] rd_addr;

  assign opcode = inst[6:0];
  assign rd_addr = inst[11:7];

  // expecpt B and S
  assign reg_write = (opcode != `OPC_BRANCH) && (opcode != `OPC_STORE) && (!(rd_addr == 5'd0));
  assign mem_write = (opcode == `OPC_STORE);
  assign mem_read = opcode == `OPC_LOAD;

  // Decide utype rs1 is zero(LUI) or PC(AUIPC/J-type), rs2 must be immediate
  assign utype_src = (opcode == `OPC_AUIPC) || (opcode == `OPC_JAL) || (opcode == `OPC_JALR);
  // Decide jtype rs2 is immediate or 4(JAL/JALR). 
  // When jtype_src is asserted, utype_src must be asserted to use PC as rs1
  assign jtype_src = (opcode == `OPC_JAL) || (opcode == `OPC_JALR);

  assign branch = opcode == `OPC_BRANCH;
  assign jump = (opcode == `OPC_JAL) || (opcode == `OPC_JALR);
  // jalr_src is used to determine which is used to calculate next pc address
  assign jalr_src = opcode == `OPC_JALR;
  
  assign csr_we = opcode == `OPC_CSR;
  assign csr_rd = opcode == `OPC_CSR && (!(rd_addr == 5'd0));

  assign mem_to_reg = (opcode == `OPC_CSR) ? 2'b01:
                      (opcode == `OPC_LOAD) ? 2'b10: 2'b00;


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
    if (opcode == `OPC_LUI || utype_src) alu_src_a = 2'b01;
    else alu_src_a = 2'b00;
  end

  always @(*) begin
    if (opcode == `OPC_LOAD  || 
        opcode == `OPC_STORE || 
        opcode == `OPC_ARI_ITYPE ||
        opcode == `OPC_LUI ||
        opcode == `OPC_AUIPC || jtype_src) begin
      // Immediate
      alu_src_b = 2'b01;
    end else begin
      // FIXME
      alu_src_b = 2'b00;
    end
  end

endmodule
