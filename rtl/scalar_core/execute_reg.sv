// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


import my_pkg::*;

module execute_reg
(
  input  logic        clk,
  input  logic        en,
  input  logic        clr,

  // Control Signals
  input  logic        RegWriteD,
  input  logic  [1:0] ResultSrcD,
  input  logic        MemWriteD,
  input  logic  [1:0] s_selD,
  input  logic  [1:0] l_selD,
  input  logic        u_loadD,
  input  logic        JumpD,
  input  logic        JumprD,
  input  logic        BranchD,
  input  logic  [1:0] ALUResultSrcD,
  input  ALUOp        ALUControlD,
  input  logic        ALUSrcD,

  output logic        RegWriteE,
  output logic  [1:0] ResultSrcE,
  output logic        MemWriteE,
  output logic  [1:0] s_selE,
  output logic  [1:0] l_selE,
  output logic        u_loadE,
  output logic        JumpE,
  output logic        JumprE,
  output logic        BranchE,
  output logic  [1:0] ALUResultSrcE,
  output ALUOp        ALUControlE,
  output logic        ALUSrcE,

  // PC, Register Address, Data
  input  logic [31:0] InstrD,  // NEW: Pass full instruction to Execute
  input  logic [31:0] RD1D,
  input  logic [31:0] RD2D,
  input  logic [31:0] PCD,
  input  logic  [4:0] Rs1D,
  input  logic  [4:0] Rs2D,
  input  logic  [4:0] RdD,
  input  logic [31:0] ImmExtD,
  input  logic [31:0] PCPlus4D,
  
  output logic [31:0] InstrE,
  output logic [31:0] RD1E,
  output logic [31:0] RD2E,
  output logic [31:0] PCE,
  output logic  [4:0] Rs1E,
  output logic  [4:0] Rs2E,
  output logic  [4:0] RdE,
  output logic [31:0] ImmExtE,
  output logic [31:0] PCPlus4E, 

  // --- Vector Coprocessor Trigger ---
  input  logic        vector_req_D,  // Incoming trigger from Control Unit
  output logic        vector_req_E   // Outgoing trigger to Vicuna Wrapper
);

  always_ff @(posedge clk) begin

    if(clr) begin
      RegWriteE     <=  1'b0;
      ResultSrcE    <=  2'b0;
      MemWriteE     <=  1'b0;
      s_selE        <=  2'b0;
      l_selE        <=  2'b0;
      u_loadE       <=  1'b0;
      JumpE         <=  1'b0;
      JumprE        <=  1'b0;
      BranchE       <=  1'b0;
      ALUResultSrcE <=  2'b0;
      ALUControlE   <=  OP_ADD;
      ALUSrcE       <=  1'b0;
      RD1E          <= 32'b0;
      RD2E          <= 32'b0;
      PCE           <= 32'b0;
      Rs1E          <=  5'b0;
      Rs2E          <=  5'b0;
      RdE           <=  5'b0;
      ImmExtE       <= 32'b0;
      PCPlus4E      <= 32'b0;
      vector_req_E  <= 1'b0;   // NEW: Kill trigger on flush
      InstrE        <= 32'b0;  // NEW: Clear instruction on flush
    end else

    if(en) begin
      RegWriteE     <= RegWriteD;
      ResultSrcE    <= ResultSrcD;
      MemWriteE     <= MemWriteD;
      s_selE        <= s_selD;
      l_selE        <= l_selD;
      u_loadE       <= u_loadD;
      JumpE         <= JumpD;
      JumprE        <= JumprD;
      BranchE       <= BranchD;
      ALUResultSrcE <= ALUResultSrcD;
      ALUControlE   <= ALUControlD;
      ALUSrcE       <= ALUSrcD;
      RD1E          <= RD1D;
      RD2E          <= RD2D;
      PCE           <= PCD;
      Rs1E          <= Rs1D;
      Rs2E          <= Rs2D;
      RdE           <= RdD;
      ImmExtE       <= ImmExtD;
      PCPlus4E      <= PCPlus4D;
      vector_req_E  <= vector_req_D; // NEW: Pass trigger to Execute
      InstrE        <= InstrD;       // NEW: Pass instruction to Execute
    end

  end

endmodule
