// =============================================================================
// i_mem_synth.sv - SYNTHESIS VERSION
// -----------------------------------------------------------------------------
// Synthesizable instruction memory using inferred block RAM.
// Replaces $readmemh (simulation-only) with synchronous read inference.
// NOTE: This file is for logic synthesis only (Cadence Genus).
//       For functional simulation, use the simulation version which uses
//       $readmemh for program loading via i_mem_sim.sv.
// Interface change vs simulation version:
//   - Added clk, rst ports (required for synchronous RAM inference)
//   - Read output is registered (1-cycle latency vs async in sim version)
// =============================================================================
 
module i_mem #(
  parameter int SIZE_POW2 = 10,
  parameter int BASE_ADDR = 32'h0000_0000
)(
  input  logic        clk,
  input  logic        rst,
  input  logic [31:0] A,
  output logic [31:0] RD
);
 
  localparam int MEM_BYTES = 1 << SIZE_POW2;
  localparam int WORDS     = MEM_BYTES / 4;
 
  // Synthesis attribute: infer as block RAM
  (* ram_style = "block" *) logic [31:0] IMEM [0:WORDS-1];
 
  // Synchronous registered read - standard block RAM inference pattern
  // recognized by Genus and all major synthesis tools
  always_ff @(posedge clk) begin
    if (rst) begin
      RD <= 32'h00000013; // NOP on reset
    end else if (A >= BASE_ADDR && A < BASE_ADDR + MEM_BYTES) begin
      RD <= IMEM[(A - BASE_ADDR) >> 2];
    end else begin
      RD <= 32'h00000013; // NOP for out-of-range
    end
  end
 
endmodule