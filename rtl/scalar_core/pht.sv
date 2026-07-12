// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module pht
(
  input  logic       clk,        // Clock
  input  logic       reset,      // Reset
  input  logic       BranchE,    // Branch Detect from EX stage
  input  logic       br_actualE, // Actual branch outcome from EX stage
  input  logic [9:0] pht_indexF, // Address to predict next branch outcome
  input  logic [9:0] pht_indexE, // Address to update counters
  output logic       pht_taken   // Predicted branch outcome
);

  logic [1:0] PHT_Array [0:1023];
  logic [1:0] count;

  always_comb begin
    case (PHT_Array[pht_indexE])
                               // Taken : Not Taken
      2'b00: count = br_actualE ? 2'b01 : 2'b00; // Strong Not Taken
      2'b01: count = br_actualE ? 2'b10 : 2'b00; // Weak Not Taken
      2'b10: count = br_actualE ? 2'b11 : 2'b01; // Weak Taken
      2'b11: count = br_actualE ? 2'b11 : 2'b10; // Strong Taken
    endcase
  end

  // Synchronous Write Logic
  always_ff @(posedge clk) begin
    if (reset) begin
        // Initialize counters (Weak Not Taken 2'b01)
        for (int i = 0; i < 1024; i++) begin
            PHT_Array[i] <= 2'b01; 
        end
    end else

    if (BranchE) begin
      PHT_Array[pht_indexE] <= count;
    end
  end

  // Asynchronous Read logic
  assign pht_taken = PHT_Array[pht_indexF][1];

endmodule
