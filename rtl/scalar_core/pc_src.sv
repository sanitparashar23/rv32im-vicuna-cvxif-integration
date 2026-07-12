// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module pc_src
(
  input  logic       Jump,
  input  logic       Jumpr,
  input  logic       Branch,
  input  logic       br_taken,
  input  logic       br_predict,
  output logic [1:0] PCSrc,
  output logic       mispredict
);

  assign PCSrc = Jump | (Branch & br_taken) ? 2'b01 : // PCE + ImmExtE
                 Jumpr                      ? 2'b10 : // ALUResultE & ~1
                                              2'b00 ; // PCF + 4 | PCE + 4 with branch predictor

  assign mispredict = ((Jump | Jumpr) & !br_predict) | (Branch & (br_taken != br_predict));

endmodule
