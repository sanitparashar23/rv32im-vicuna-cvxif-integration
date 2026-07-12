// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Modified by Sanit Parashar for RV32IM-Vicuna CV-X-IF integration (2026)
// See THIRD_PARTY_LICENSES.md for details on scope of changes

module d_mem #(
  parameter int SIZE_POW2 = 12,              // HARDCODED to 2^12 = 4096 bytes (1024 words)
  parameter int BASE_ADDR = 32'h8000_0000
)(
  input  logic        clk,
  input  logic        WE,                    // Restored uppercase WE
  input  logic [3:0]  byte_en,               // Restored byte_en
  input  logic [31:0] A,                     // Address
  input  logic [31:0] WD,                    // Write Data
  output logic [31:0] RD                     // Read Data
);

  localparam int MEM_BYTES = 1 << SIZE_POW2;
  localparam int WORDS     = MEM_BYTES / 4;

  logic [31:0] DMEM [0:WORDS-1];
  logic [29:0] word_idx;

  assign word_idx = (A - BASE_ADDR) >> 2;

  // Initialize ALL memory to 0 to prevent X-propagation
  initial begin
    for (int i = 0; i < WORDS; i++) begin
      DMEM[i] = 32'h00000000;
    end
    
    // Attempt to load hex if it exists
    $readmemh(`DMEM_HEX, DMEM);
  end

  // Synchronous Write with Byte Enables
  always_ff @(posedge clk) begin
    if (WE) begin
      if (A >= BASE_ADDR && A < BASE_ADDR + MEM_BYTES) begin
        if (byte_en[0]) DMEM[word_idx][7:0]   <= WD[7:0];
        if (byte_en[1]) DMEM[word_idx][15:8]  <= WD[15:8];
        if (byte_en[2]) DMEM[word_idx][23:16] <= WD[23:16];
        if (byte_en[3]) DMEM[word_idx][31:24] <= WD[31:24];
      end
    end
  end

  // Combinational Read (with safety bounds)
  assign RD = (A >= BASE_ADDR && A < BASE_ADDR + MEM_BYTES) ? 
              DMEM[word_idx] : 
              32'h00000000;

endmodule