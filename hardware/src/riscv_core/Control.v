// Disc: Generate control signals decided by opcode
`include "Opcode.vh"
module CONTROL #(
  parameter INST_WIDTH = 32
) (
  input [INST_WIDTH - 1:0] inst,
  output reg_write,
  output mem_write,
  output mem_read,
  output reg [1:0] mem_to_reg,
  output jalr_src,
  output branch,
  output jump,
  output reg [1:0] alu_op,
  output reg [1:0] alu_src_a,
  output reg [1:0] alu_src_b,
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

  assign branch = opcode == `OPC_BRANCH;
  assign jump = (opcode == `OPC_JAL) || (opcode == `OPC_JALR);
  // jalr_src is used to determine which is used to calculate next pc address
  assign jalr_src = opcode == `OPC_JALR;

  assign csr_we = opcode == `OPC_CSR;
  assign csr_rd = opcode == `OPC_CSR && (!(rd_addr == 5'd0));

  always @(*) begin
    case (opcode)
      `OPC_LOAD: mem_to_reg = 2'b10;
      `OPC_CSR: mem_to_reg = 2'b01;
      `OPC_JAL: mem_to_reg = 2'b11;
      `OPC_JALR: mem_to_reg = 2'b11;
      default: mem_to_reg = 2'b00;
    endcase
  end

  always @(*) begin
    case (opcode)
      `OPC_ARI_ITYPE: alu_op = 2'b11;
      `OPC_ARI_RTYPE: alu_op = 2'b10;
      `OPC_BRANCH: alu_op = 2'b01;
      default: alu_op = 2'b00;
    endcase
  end

  always @(*) begin
    if (opcode == `OPC_AUIPC) begin
      // PC
      alu_src_a = 2'b10;
    end else begin
      // rs1
      alu_src_a = 2'b00;
    end
  end

  always @(*) begin
    // if (opcode == `OPC_JAL || opcode == `OPC_JALR) begin
    //   // immediate 4
    //   alu_src_b = 2'b10;
    // end else 
    if (opcode == `OPC_LOAD  || 
                 opcode == `OPC_STORE || 
                 opcode == `OPC_ARI_ITYPE ||
                 opcode == `OPC_LUI ||
                 opcode == `OPC_AUIPC) begin
      // Immediate
      alu_src_b = 2'b01;
    end else begin
      // rs2
      alu_src_b = 2'b00;
    end
  end

endmodule
