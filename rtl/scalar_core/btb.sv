// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module btb (
  input  logic        clk,
  input  logic        reset,
  input  logic [31:0] PCF,        // Tag (PC of current IF inst) for reading
  input  logic [31:0] PCE,        // Tag (PC of branch) for writing
  input  logic        JumpE,      // Jump detect from EX stage
  input  logic        JumprE,     // Jumpr detect from EX stage
  input  logic        BranchE,    // Branch detect from EX stage
  input  logic        br_actualE, // Actual branch outcome from EX stage
  input  logic [31:0] PCTargetE,  // Branch/JAL address to write
  input  logic [31:0] ALUResultE, // JALR address to write
  output logic        btb_hit,    // Asserts if match found
  output logic [31:0] target_addr // Predicted destination
);

  // Update BTB on taken branches
  logic br_takenE;                
  assign br_takenE = BranchE & br_actualE;

  // BTB Entry Structure: {valid_bit, tag, target_address}
  // Using 10-bit index, 32-bit tag, 32-bit target (65 bits total per entry)
  logic [64:0] BTB_Array [0:1023]; 

  // Read Logic (combinational access in IF stage)
  logic [64:0] read_entry;
  assign read_entry = BTB_Array[PCF[11:2]];

  logic valid_bit;
  logic [31:0] entry_tag;

  assign valid_bit = read_entry[64];
  assign entry_tag = read_entry[63:32];
  assign target_addr = read_entry[31:0];

  // Check for a hit: must be valid AND tags must match
  assign btb_hit = valid_bit && (entry_tag == PCF);

  // Write Logic (synchronous update from EX stage)
  always_ff @(posedge clk) begin
    if (reset) begin
      for (int i = 0; i < 1024; i++) begin
        BTB_Array[i] <= 65'd0; // Clear valid bits on reset
      end
    end else

    if (JumpE | JumprE | br_takenE) begin
      // Combine all fields into a single entry to write
      BTB_Array[PCE[11:2]] <= JumprE ? {1'b1, PCE, ALUResultE} : {1'b1, PCE, PCTargetE};
    end
  end

endmodule
