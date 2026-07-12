// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Modified by Sanit Parashar for RV32IM-Vicuna CV-X-IF integration (2026)
// See THIRD_PARTY_LICENSES.md for details on scope of changes

module i_mem #(
  parameter int SIZE_POW2 = 10,              // 2^SIZE_POW2 bytes (e.g., 2^10 = 1 KB)
  parameter int BASE_ADDR = 32'h0000_0000    // Starting Address
)(
  input  logic [31:0] A,                     // Instruction Address
  output logic [31:0] RD                     // Instruction
);

  localparam int MEM_BYTES = 1 << SIZE_POW2;
  localparam int WORDS     = MEM_BYTES / 4;

  logic [31:0] IMEM [0:WORDS-1];

  initial begin
    // 1. FILL WITH NOPs TO PREVENT X-PROPAGATION
    for (int i = 0; i < WORDS; i++) begin
      IMEM[i] = 32'h00000013; 
    end

    // 2. LOAD YOUR PROGRAM
    $readmemh(`IMEM_HEX, IMEM);

    if (IMEM[0] === 32'bx || IMEM[0] === 32'b0)
      $display("WARNING: IMEM[0]=0 or X — check that i_mem.hex loaded correctly!");
    else
      $display("[IMEM] Loaded OK. IMEM[0]=%08h", IMEM[0]);
  end

  // 3. SAFE READ
  assign RD = (A >= BASE_ADDR && A < BASE_ADDR + MEM_BYTES) ? 
              IMEM[(A - BASE_ADDR) >> 2] : 
              32'h00000013; 

endmodule