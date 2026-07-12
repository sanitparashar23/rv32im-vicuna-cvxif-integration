// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module gbh
(
  input  logic       clk,        // Clock
  input  logic       reset,      // Reset
  input  logic       BranchE,    // Update GHR Enable
  input  logic       br_actualE, // Actual branch outcome
  output logic [9:0] gbh_reg     // The current history value
);

  always_ff @(posedge clk) begin
    if (reset) begin
      gbh_reg <= 10'b0;
    end else if (BranchE) begin
      // Shift in the new branch resolution when branch instruction is detected
      gbh_reg <= {gbh_reg[8:0], br_actualE};
    end
  end

endmodule
