// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module reg_file
(
  input  logic        clk, // Clock
  input  logic        WE3, // Write Enable

  // Read Ports
  input  logic  [4:0] A1,  // Read Address 1
  input  logic  [4:0] A2,  // Read Address 2
  output logic [31:0] RD1, // Read Data 1
  output logic [31:0] RD2, // Read Data 2

  // Write Ports
  input  logic  [4:0] A3,  // Write Address
  input  logic [31:0] WD3  // Write Data
);

  // Internal Register Array
  logic [31:0] cpureg [0:31];

  // Synchronous Write Logic
  // Harris & Harris example requires this to be negedge
  // for pipelined design to work correctly
  always_ff @(negedge clk) begin
    if (WE3 && (A3!= 5'b0)) begin
      cpureg[A3] <= WD3;
    end
  end

  // Asynchronous Read logic
  assign RD1 = (A1==5'b0) ? 32'b0 : cpureg[A1];
  assign RD2 = (A2==5'b0) ? 32'b0 : cpureg[A2];

endmodule
