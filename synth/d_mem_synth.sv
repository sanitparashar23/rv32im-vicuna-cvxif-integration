// =============================================================================
// d_mem_synth.sv - SYNTHESIS VERSION
// -----------------------------------------------------------------------------
// Synthesizable data memory using inferred block RAM.
// Removes $readmemh and initial block (simulation-only constructs).
// Write path is unchanged (synchronous with byte enables).
// Read path is unchanged (combinational/async).
// NOTE: This file is for logic synthesis only (Cadence Genus).
//       For functional simulation, use the simulation version which uses
//       $readmemh for data initialization via d_mem_sim.sv.
// =============================================================================

module d_mem #(
  parameter int SIZE_POW2 = 12,
  parameter int BASE_ADDR = 32'h8000_0000
)(
  input  logic        clk,
  input  logic        WE,
  input  logic [3:0]  byte_en,
  input  logic [31:0] A,
  input  logic [31:0] WD,
  output logic [31:0] RD
);

  localparam int MEM_BYTES = 1 << SIZE_POW2;
  localparam int WORDS     = MEM_BYTES / 4;

  // Synthesis attribute: infer as block RAM
  (* ram_style = "block" *) logic [31:0] DMEM [0:WORDS-1];

  logic [29:0] word_idx;
  assign word_idx = (A - BASE_ADDR) >> 2;

  // Synchronous write with byte enables - identical to simulation version
  // $readmemh removed: memory contents undefined at reset (X) in synthesis
  // In production flow, memory contents loaded via scan chain or memory compiler
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

  // Combinational read - unchanged from simulation version
  assign RD = (A >= BASE_ADDR && A < BASE_ADDR + MEM_BYTES) ?
              DMEM[word_idx] :
              32'h00000000;

endmodule