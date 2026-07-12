// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)


module writeback_reg
(
  input  logic        clk,

  // Control Signals
  input  logic        RegWriteM,
  input  logic  [1:0] ResultSrcM,
  input  logic  [1:0] l_selM,
  input  logic        u_loadM,

  output logic        RegWriteW,
  output logic  [1:0] ResultSrcW,
  output logic  [1:0] l_selW,
  output logic        u_loadW,

  // PC, Register Address, Data
  input  logic [31:0] ALUResultM,
  input  logic [31:0] ReadDataM,
  input  logic [31:0] PCTargetM,
  input  logic  [4:0] RdM,
  input  logic [31:0] PCPlus4M,

  output logic [31:0] ALUResultW,
  output logic [31:0] ReadDataW,
  output logic [31:0] PCTargetW,
  output logic  [4:0] RdW,
  output logic [31:0] PCPlus4W
);

  always_ff @(posedge clk) begin
    RegWriteW  <= RegWriteM;
    ResultSrcW <= ResultSrcM;
    l_selW     <= l_selM;
    u_loadW    <= u_loadM;
    ALUResultW <= ALUResultM;
    ReadDataW  <= ReadDataM;
    PCTargetW  <= PCTargetM;
    RdW        <= RdM;
    PCPlus4W   <= PCPlus4M;
  end

endmodule
