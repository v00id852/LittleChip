// Module Name: IMM_GEN
// Discription: Immediate generator. The module generates immediate 
// depends on the instruction type.
//
module IMM_GEN #(
  parameter IWIDTH = 32,
  parameter DWIDTH = 32
) (
  input  [IWIDTH - 1:0] inst_in,
  output [DWIDTH - 1:0] imm_out
);

  wire [DWIDTH - 1:0] imm_I, imm_S, imm_B, imm_U, imm_J;

  // B is similar to S, J is similar to U
  assign imm_I = {{(DWIDTH - 12) {inst_in[31]}}, inst_in[31:20]};
  assign imm_S = {{(DWIDTH - 12) {inst_in[31]}}, inst_in[31:25], inst_in[11:7]};
  assign imm_B = {
    {(DWIDTH - 13) {inst_in[31]}}, inst_in[31], inst_in[7], inst_in[30:25], inst_in[11:8], 1'b0
  };
  assign imm_U = {{(DWIDTH - 32) {inst_in[31]}}, inst_in[31:12], 12'b0};
  assign imm_J = {
    {(DWIDTH - 21) {inst_in[31]}}, inst_in[31], inst_in[19:12], inst_in[20], inst_in[30:21], 1'b0
  };

  reg [DWIDTH - 1:0] imm_out;

  always @(*) begin
    case (inst_in[6:5])
      2'b00: begin
        if (inst_in[2] == 1'b1) imm_out = imm_U;
        else imm_out = imm_I;
      end
      2'b01: begin
        if (inst_in[4] == 1'b0) imm_out = imm_S;
        else imm_out = imm_U;
      end
      2'b11: begin
        if (inst_in[3:2] == 2'b11) imm_out = imm_J;
        else if (inst_in[3:2] == 2'b01) imm_out = imm_I;
        else if (inst_in[3:2] == 2'b00) imm_out = imm_B;
        else imm_out = {DWIDTH{1'b0}};
      end
      default: imm_out = {DWIDTH{1'b0}};
    endcase
  end

endmodule
