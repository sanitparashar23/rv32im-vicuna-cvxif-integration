// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module memory_reg
(
  input  logic        clk,
  input  logic        clr,

  // Control Signals
  input  logic        RegWriteE,
  input  logic  [1:0] ResultSrcE,
  input  logic        MemWriteE,
  input  logic  [1:0] s_selE,
  input  logic  [1:0] l_selE,
  input  logic        u_loadE,
  input  logic  [1:0] ALUResultSrcE,

  output logic        RegWriteM,
  output logic  [1:0] ResultSrcM,
  output logic        MemWriteM,
  output logic  [1:0] s_selM,
  output logic  [1:0] l_selM,
  output logic        u_loadM,
  output logic  [1:0] ALUResultSrcM,

  // PC, Register Address, Data
  input  logic [31:0] ALUResultE,
  input  logic [31:0] WriteDataE,
  input  logic [31:0] PCTargetE,
  input  logic  [4:0] RdE,
  input  logic [31:0] PCPlus4E,

  output logic [31:0] ALUResultM,
  output logic [31:0] WriteDataM,
  output logic [31:0] PCTargetM,
  output logic  [4:0] RdM,
  output logic [31:0] PCPlus4M
);

  always_ff @(posedge clk) begin

    if(clr) begin
      RegWriteM     <=  1'b0;
      ResultSrcM    <=  2'b0;
      MemWriteM     <=  1'b0;
      s_selM        <=  2'b0;
      l_selM        <=  2'b0;
      u_loadM       <=  1'b0;
      ALUResultSrcM <=  2'b0;
      ALUResultM    <= 32'b0;
      WriteDataM    <= 32'b0;
      PCTargetM     <= 32'b0;
      RdM           <=  5'b0;
      PCPlus4M      <= 32'b0;
    end else

    begin
      RegWriteM     <= RegWriteE;
      ResultSrcM    <= ResultSrcE;
      MemWriteM     <= MemWriteE;
      s_selM        <= s_selE;
      l_selM        <= l_selE;
      u_loadM       <= u_loadE;
      ALUResultSrcM <= ALUResultSrcE;
      ALUResultM    <= ALUResultE;
      WriteDataM    <= WriteDataE;
      PCTargetM     <= PCTargetE;
      RdM           <= RdE;
      PCPlus4M      <= PCPlus4E;
    end

  end

endmodule
