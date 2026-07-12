// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module multiplier_1c
(
  input  logic [31:0] opA,      // Operand A
  input  logic [31:0] opB,      // Operand B
  input  logic  [1:0] sign_sel, // Sign Selection

  output logic [63:0] product   // Result
);

  logic [31:0] newA, newB;
  logic        sign;
  logic [63:0] u_product;

  always_comb begin

    case(sign_sel)
      // mul,mulh
      2'b00 : begin
                newA = opA[31] ? ~opA + 1'b1 : opA;
                newB = opB[31] ? ~opB + 1'b1 : opB;
                sign = opA[31] ^ opB[31];
              end
      // mulhsu
      2'b01 : begin
                newA = opA[31] ? ~opA + 1'b1 : opA;
                newB = opB;
                sign = opA[31];
              end
      // mulhu
      2'b10 : begin
                newA = opA;
                newB = opB;
                sign = 1'b0;
              end
      // signed/signed by default
    default : begin
                newA = opA[31] ? ~opA + 1'b1 : opA;
                newB = opB[31] ? ~opB + 1'b1 : opB;
                sign = opA[31] ^ opB[31];
              end
    endcase

    u_product = newA * newB;
      product = sign ? ~u_product + 1'b1 : u_product;

  end

endmodule
