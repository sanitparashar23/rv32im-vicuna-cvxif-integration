// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module divider_1c
(
  input  logic [31:0] numA,     // Operand A
  input  logic [31:0] denB,     // Operand B
  input  logic        sign_sel, // Sign Selection
  output logic [31:0] quotient, // Quotient
  output logic [31:0] remainder // Remainder
);

  logic [31:0] newA, newB;
  logic        sign;
  logic [31:0] u_quotient, u_remainder;

  always_comb begin

    case(sign_sel)
      // div,rem
      1'b0 : begin
               newA = numA[31] ? ~numA + 1'b1 : numA;
               newB = denB[31] ? ~denB + 1'b1 : denB;
               sign = numA[31] ^ denB[31];
             end
      // divu,remu
      1'b1 : begin
               newA = numA;
               newB = denB;
               sign = 1'b0;
             end
      // signed/signed by default
   default : begin
               newA = numA[31] ? ~numA + 1'b1 : numA;
               newB = denB[31] ? ~denB + 1'b1 : denB;
               sign = numA[31] ^ denB[31];
             end
    endcase

    u_quotient  = newA / newB;
    u_remainder = newA % newB;

      quotient  = (denB==32'b0) ? 32'hFFFFFFFF       :
                           sign ? ~u_quotient + 1'b1 :
                                   u_quotient;

      remainder = (denB==32'b0) ? numA                :
                           sign ? ~u_remainder + 1'b1 :
                                   u_remainder;

  end

endmodule
