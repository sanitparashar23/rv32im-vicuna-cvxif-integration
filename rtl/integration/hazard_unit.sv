// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Modified by Sanit Parashar for RV32IM-Vicuna CV-X-IF integration (2026)
// See THIRD_PARTY_LICENSES.md for details on scope of changes

module hazard_unit (
  input  logic [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE,
  input  logic       mispredictE,
  input  logic [1:0] ResultSrcE,
  input  logic       BusyE,
  input  logic [4:0] RdM,
  input  logic       RegWriteM,
  input  logic [4:0] RdW,
  input  logic       RegWriteW,
  input  logic       vicuna_busy_E, 
  output logic       StallF, StallD, FlushD, StallE, FlushE, FlushM,
  output logic [1:0] ForwardAE, ForwardBE
);
  logic lStall, aluStall, jbFlush;
  
  always_comb begin
    // Forwarding Logic
    ForwardAE = (Rs1E==RdM) & RegWriteM & (Rs1E!=0) ? 2'b10 :
                (Rs1E==RdW) & RegWriteW & (Rs1E!=0) ? 2'b01 : 2'b00;
                
    ForwardBE = (Rs2E==RdM) & RegWriteM & (Rs2E!=0) ? 2'b10 :
                (Rs2E==RdW) & RegWriteW & (Rs2E!=0) ? 2'b01 : 2'b00;
                
    lStall = (ResultSrcE==2'b01) & ((Rs1D==RdE) | (Rs2D==RdE));
  end
  
  assign jbFlush = mispredictE;
  assign aluStall = BusyE;
  
  always_comb begin
    // Freeze Fetch, Decode, and Execute while Vicuna is crunching math
    StallF = lStall | aluStall | vicuna_busy_E;
    StallD = lStall | aluStall | vicuna_busy_E; 
    FlushD = jbFlush;
    StallE = aluStall | vicuna_busy_E;
    FlushE = lStall | jbFlush;
    FlushM = aluStall; 
  end
endmodule