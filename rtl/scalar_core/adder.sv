// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module adder
(
  input  logic [31:0] opA,      // Operand A
  input  logic [31:0] opB,      // Operand B
  input  logic        sub_en,   // Subtraction Enable

  output logic [31:0] sum,      // Result
  output logic        overflow, // Overflow Flag
  output logic        carry,    // Carry Flag
  output logic        negative, // Negative Flag
  output logic        zero      // Zero Flag
);

  logic [31:0] newB;

  always_comb begin

  newB = sub_en ? ~opB : opB;

  {carry,sum} = opA + newB + sub_en;

  zero     = ~|sum;
  negative = sum[31];
  overflow = ~(opA[31] ^ opB[31] ^ sub_en) & (opA[31] ^ sum[31]);

  end

endmodule
