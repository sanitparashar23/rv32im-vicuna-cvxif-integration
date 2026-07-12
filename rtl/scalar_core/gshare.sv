// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


import my_pkg::*;

module gshare
(
  input  logic        clk,         // Clock
  input  logic        reset,       // Reset
  input  logic [31:0] PCF,         // PC in IF
  input  logic [31:0] PCPlus4F,    // PC+4 in IF
  input  opcode       opF,         // opcode in IF
  input  logic [31:0] PCE,         // PC in EX
  input  logic [31:0] PCPlus4E,    // PC+4 in EX
  input  logic  [1:0] PCSrcE,      // PC Source in EX
  input  logic        JumpE,       // Jump detect from EX stage
  input  logic        JumprE,      // Jumpr detect from EX stage
  input  logic        BranchE,     // Branch detect from EX stage
  input  logic        br_actualE,  // Actual branch outcome from EX stage
  input  logic [31:0] PCTargetE,   // Branch/JAL address to write
  input  logic [31:0] ALUResultE,  // JALR address to write
  input  logic        mispredictE, // Branch misprediction
  output logic        br_predictE, // Branch prediction
  output logic [31:0] PCNextF,     // Next fetch address

  // Stall/Flush signals from Hazard Unit
  input  logic        StallD,
  input  logic        FlushD,
  input  logic        StallE,
  input  logic        FlushE
);

  logic  [9:0] gbh_reg;
  logic  [9:0] pht_indexF, pht_indexD, pht_indexE;
  logic        br_predictF, br_predictD;
  logic        pht_taken, hit;
  logic [31:0] target_addr, PCNext_actualF;

always_ff @(posedge clk) begin
//***************************************************************************
//Decode Register
//***************************************************************************
  if(FlushD) begin
    pht_indexD  <= 10'b0;
    br_predictD <=  1'b0;
  end else

  if(~StallD) begin
    pht_indexD  <= pht_indexF;
    br_predictD <= br_predictF;
  end
//***************************************************************************
//Decode Register
//***************************************************************************

//***************************************************************************
//Execute Register
//***************************************************************************
  if(FlushE) begin
    pht_indexE  <= 10'b0;
    br_predictE <=  1'b0;
  end else

  if(~StallE) begin
    pht_indexE  <= pht_indexD;
    br_predictE <= br_predictD;
  end
//***************************************************************************
//Execute Register
//***************************************************************************
end

  gbh u_gbh(
    .clk(clk),
    .reset(reset),
    .BranchE(BranchE),       // Update GBH
    .br_actualE(br_actualE), // Actual branch outcome
    .gbh_reg(gbh_reg)        // The current history value
  );

  assign pht_indexF = gbh_reg ^ PCF[11:2];
  pht u_pht(
    .clk(clk),
    .reset(reset),
    .BranchE(BranchE),       // Update PHT
    .br_actualE(br_actualE), // Actual branch outcome
    .pht_indexF(pht_indexF), // Address to predict next branch outcome
    .pht_indexE(pht_indexE), // Address to update counters
    .pht_taken(pht_taken)    // Predicted branch outcome
  );

  btb u_btb(
    .clk(clk),
    .reset(reset),
    .PCF(PCF),                     // Tag (PC of current IF inst) for reading
    .PCE(PCE),                     // Tag (PC of branch) for writing
    .JumpE(JumpE),                 // Jump detect from EX stage
    .JumprE(JumprE),               // Jumpr detect from EX stage
    .BranchE(BranchE),             // Branch detect from EX stage
    .br_actualE(br_actualE),       // Actual branch outcome from EX stage
    .PCTargetE(PCTargetE),         // Target address to write
    .ALUResultE(ALUResultE & ~1),  // JALR address to write
    .btb_hit(hit),                 // Asserts if match found
    .target_addr(target_addr)      // Predicted destination
  );

  assign jump_taken  = (opF==I_TYPE_a) | (opF==J_TYPE); // JALR | JAL
  assign br_predictF = (pht_taken | jump_taken) & hit;

  // True PCNextF
  mux3 u_pcnext_actual(
    .d0(PCPlus4E),        // PCSrcE[1] ? ALUResultE & ~1 :
    .d1(PCTargetE),       // PCSrcE[0] ? PCTargetE       :
    .d2(ALUResultE & ~1), //             PCPlus4E
    .s(PCSrcE),
    .y(PCNext_actualF)
  );

  // Predicted PCNextF
  mux3 u_pcnext_predicted(
    .d0(PCPlus4F),                 // mispredictE ? PCNext_actualF :
    .d1(target_addr),              // br_predictF ? target_addr    :
    .d2(PCNext_actualF),           //               PCPlus4F
    .s({mispredictE,br_predictF}),
    .y(PCNextF)
  );

endmodule
