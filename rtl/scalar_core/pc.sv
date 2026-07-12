// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module pc
(
  input  logic        clk,
  input  logic        reset,
  input  logic        en,
  input  logic [31:0] PCNext, // Next PC
  output logic [31:0] PC      // PC
);

  always_ff @(posedge clk) begin

    if(reset) begin
      PC <= 32'b0;
    end else

    if(en) begin
      PC <= PCNext;
    end

  end

endmodule
