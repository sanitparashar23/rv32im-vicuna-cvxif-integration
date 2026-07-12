// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Modified by Sanit Parashar for RV32IM-Vicuna CV-X-IF integration (2026)
// See THIRD_PARTY_LICENSES.md for details on scope of changes

import my_pkg::*;

module rv32im
(
  input  logic        clk,       // Clock
  input  logic        reset,     // Reset

  // Instruction Memory Ports
  input  logic [31:0] Instr,     // Instruction
  output logic [31:0] PC,        // Instruction Address

  // Data Memory Ports
  input  logic [31:0] ReadData,  // Read Data
  output logic        MemWrite,  // Write Enable
  output logic  [3:0] byte_en,   // Byte Enable
  output logic [31:0] ALUResult, // Read/Write Address
  output logic [31:0] WriteData,  // Write Data

  // ==========================================
  // NEW: COPROCESSOR MEMORY PORTS (To Arbiter)
  // ==========================================
  output logic        vicuna_busy,
  output logic        v_mem_valid,
  output logic        v_mem_we,
  output logic [3:0]  v_mem_be,
  output logic [31:0] v_mem_addr,
  output logic [31:0] v_mem_wdata,
  input  logic        v_mem_ready,
  input  logic        v_mem_result_valid, // driven 1'b0 from top; wrapper ignores it
  input  logic [31:0] v_mem_rdata,

  output logic        v_pending_load,
  output logic        v_pending_store
);

  // Internal Connections
  logic [31:0] PCNextF ,
               PCF     , PCD          , PCE          ,
               PCPlus4F, PCPlus4D     , PCPlus4E     , PCPlus4M     , PCPlus4W     ,
                                        PCTargetE    , PCTargetM    , PCTargetW    ;
  logic [31:0] InstrF  , InstrD                                                    ;
  logic [31:0]           RD1D         , RD1E                                       ;
  logic [31:0]           RD2D         , RD2E                                       ;
  logic  [4:0]           Rs1D         , Rs1E                                       ;
  logic  [4:0]           Rs2D         , Rs2E                                       ;
  logic  [4:0]           RdD          , RdE          , RdM          , RdW          ;   
  logic [31:0]           ImmExtD      , ImmExtE                                    ;
  logic                  RegWriteD    , RegWriteE    , RegWriteM    , RegWriteW    ;
  logic  [1:0]           ResultSrcD   , ResultSrcE   , ResultSrcM   , ResultSrcW   ;
  logic                  MemWriteD    , MemWriteE    , MemWriteM                   ;
  logic  [1:0]           s_selD       , s_selE       , s_selM                      ;
  logic  [1:0]           l_selD       , l_selE       , l_selM       , l_selW       ;
  logic                  u_loadD      , u_loadE      , u_loadM      , u_loadW      ;
  logic                  JumpD        , JumpE                                      ;
  logic                  JumprD       , JumprE                                     ;
  logic                  BranchD      , BranchE                                    ;
  logic  [1:0]           ALUResultSrcD, ALUResultSrcE, ALUResultSrcM               ;
  ALUOp                  ALUControlD  , ALUControlE                                ;
  logic                  ALUSrcD      , ALUSrcE                                    ;
  imm_t                  ImmSrcD                                                   ;
  logic  [1:0]                          PCSrcE                                     ;
  logic [31:0]                          SrcAE        ,
                                        SrcBE                                      ;
  logic [31:0]                          ALUResultE   , ALUResultM   , ALUResultW   ;
  logic [31:0]                                         ProALUResultM               ;
  logic                                 BusyE                                      ;
  logic [31:0]                          WriteDataE   , WriteDataM                  ;
  logic  [3:0]                                         byte_enM                    ;
  logic [31:0]                                         ProWriteDataM               ;
  logic [31:0]                                         ReadDataM    , ReadDataW    ;
  logic [31:0]                                                        ProReadDataW ;
  logic [31:0]                                                        ResultW      ;

  logic        StallF                                                              ;
  logic                  StallD                                                    ;
  logic                  FlushD                                                    ;
  logic                                 StallE                                     ;
  logic                                 FlushE                                     ;
  logic                                                FlushM                      ;
  logic  [1:0]                          ForwardAE    ,
                                        ForwardBE                                  ;

  logic                                 br_predictE                                ;
  logic                                 mispredictE                                ;

  // --- NEW: Vector Coprocessor Wires ---
  logic [31:0]                          InstrE                                     ;
  logic                                 vector_req_D                               ;
  logic                                 vector_req_E                               ;
  logic                                 vicuna_busy_E                              ;

  logic        v_xreg_we;
  logic [4:0]  v_xreg_rd;
  logic [31:0] v_xreg_data;

  assign vicuna_busy = vicuna_busy_E;
/*
  // Use this when predictor is disabled.
  // PCNextF
  mux3 u_pcnext(
    .d0(PCPlus4F),
    .d1(PCTargetE),
    .d2(ALUResultE & ~1),
    .s(PCSrcE),
    .y(PCNextF)
  );
*/
  // Gshare predictor
  gshare u_gshare(
    .clk(clk),                  // Clock
    .reset(reset),              // Reset
    .PCF(PCF),                  // PC in IF
    .PCPlus4F(PCPlus4F),        // PC+4 in IF
    .opF(InstrF[6:0]),          // opcode in IF
    .PCE(PCE),                  // PC in EX
    .PCPlus4E(PCPlus4E),        // PC+4 in EX
    .PCSrcE(PCSrcE),            // PC Source in EX
    .JumpE(JumpE),              // Jump detect from EX stage
    .JumprE(JumprE),            // Jumpr detect from EX stage
    .BranchE(BranchE),          // Branch detect from EX stage
    .br_actualE(ALUResultE[0]), // Actual branch outcome from EX stage
    .PCTargetE(PCTargetE),      // Branch/JAL address to write
    .ALUResultE(ALUResultE),    // JALR address to write
    .mispredictE(mispredictE),  // Branch misprediction
    .br_predictE(br_predictE),  // Branch prediction
    .PCNextF(PCNextF),          // Next fetch address
    // Stall/Flush signals from Hazard Unit
    .StallD(StallD),
    .FlushD(FlushD),
    .StallE(StallE),
    .FlushE(FlushE)
  );

//***************************************************************************
//Fetch Register
//***************************************************************************
  pc u_pc(
    .clk(clk),
    .reset(reset),
    .en(~StallF),
    .PCNext(PCNextF),
    .PC(PCF)
  );
//***************************************************************************
//Fetch Register
//***************************************************************************

  // PCPlus4
  assign PC = PCF;
  adder u_pc4(
    .opA(PCF),
    .opB(4),
    .sub_en(1'b0),
    .sum(PCPlus4F)
  );

//***************************************************************************
//Decode Register
//***************************************************************************
  assign InstrF = Instr;
  decode_reg u_decode_reg(
    .clk(clk),
    .en(~StallD),
    .clr(FlushD),
    .InstrF(InstrF),
    .PCF(PCF),
    .PCPlus4F(PCPlus4F),
    .InstrD(InstrD),
    .PCD(PCD),
    .PCPlus4D(PCPlus4D)
  );
//***************************************************************************
//Decode Register
//***************************************************************************

  // Control Unit
  control_unit u_control(
    .op(InstrD[6:0]),             // Op Codes
    .funct3(InstrD[14:12]),       // Function 3 Field
    .funct7b0(InstrD[25]),        // Function 7 Field, bit-0
    .funct7b5(InstrD[30]),        // Function 7 Field, bit-5
    .RegWrite(RegWriteD),         // Register Write Enable
    .ResultSrc(ResultSrcD),       // Result Select
    .MemWrite(MemWriteD),         // Memory Write Enable
    .s_sel(s_selD),               // Store Select
    .l_sel(l_selD),               // Load Select
    .u_load(u_loadD),             // Unsigned Load Enable
    .Jump(JumpD),                 // jal    Signal
    .Jumpr(JumprD),               // jalr   Signal
    .Branch(BranchD),             // branch Signal
    .ALUResultSrc(ALUResultSrcD), // ALU Result Select
    .ALUControl(ALUControlD),     // ALU Control
    .ALUSrc(ALUSrcD),             // SrcB Select. 0: RD2, 1: ImmExt
    .ImmSrc(ImmSrcD),              // Immediate Decoding
    .vector_req_o(vector_req_D)   // NEW: Vector Trigger Out
  );

  /*
  // Register File
  reg_file u_regf(
    .clk(clk),                  // Clock
    .WE3(RegWriteW),            // Write Enable
    // Read Ports
    .A1(InstrD[19:15]),         // Read Address 1
    .A2(InstrD[24:20]),         // Read Address 2
    .RD1(RD1D),                 // Read Data 1
    .RD2(RD2D),                 // Read Data 2
    // Write Ports
    .A3(RdW),                   // Write Address
    .WD3(ResultW)               // Write Data
  );
  */

  reg_file u_regf(
    .clk(clk),
    .WE3(RegWriteW | v_xreg_we),
    .A1 (InstrD[19:15]),
    .A2 (InstrD[24:20]),
    .RD1(RD1D),
    .RD2(RD2D),
    .A3 (v_xreg_we ? v_xreg_rd   : RdW),
    .WD3(v_xreg_we ? v_xreg_data : ResultW)
  );

  // Register Addresses
  always_comb begin
    Rs1D = InstrD[19:15];
    Rs2D = InstrD[24:20];
    RdD  = InstrD[11:7];
  end

  // Extend
  extend u_extend(
    .i_imm(InstrD[31:7]),       // Immediate Raw
    .ImmSrc(ImmSrcD),           // Immediate Select
    .ImmExt(ImmExtD)            // Immediate Extended
  );

//***************************************************************************
//Execute Register
//***************************************************************************
  execute_reg u_execute_reg(
    .clk(clk),
    .en(~StallE),
    .clr(FlushE),
    // Control Signals
    .RegWriteD(RegWriteD),
    .ResultSrcD(ResultSrcD),
    .MemWriteD(MemWriteD),
    .s_selD(s_selD),
    .l_selD(l_selD),
    .u_loadD(u_loadD),
    .JumpD(JumpD),
    .JumprD(JumprD),
    .BranchD(BranchD),
    .ALUResultSrcD(ALUResultSrcD),
    .ALUControlD(ALUControlD),
    .ALUSrcD(ALUSrcD),
    .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE),
    .MemWriteE(MemWriteE),
    .s_selE(s_selE),
    .l_selE(l_selE),
    .u_loadE(u_loadE),
    .JumpE(JumpE),
    .JumprE(JumprE),
    .BranchE(BranchE),
    .ALUResultSrcE(ALUResultSrcE),
    .ALUControlE(ALUControlE),
    .ALUSrcE(ALUSrcE),
    // PC, Register Address, Data
    .RD1D(RD1D),
    .RD2D(RD2D),
    .PCD(PCD),
    .Rs1D(Rs1D),
    .Rs2D(Rs2D),
    .RdD(RdD),
    .ImmExtD(ImmExtD),
    .PCPlus4D(PCPlus4D),
    .RD1E(RD1E),
    .RD2E(RD2E),
    .PCE(PCE),
    .Rs1E(Rs1E),
    .Rs2E(Rs2E),
    .RdE(RdE),
    .ImmExtE(ImmExtE),
    .PCPlus4E(PCPlus4E),
    .InstrD(InstrD),              // NEW: Instruction In
    .InstrE(InstrE),              // NEW: Instruction Out
    .vector_req_D(vector_req_D),  // NEW: Trigger In
    .vector_req_E(vector_req_E)   // NEW: Trigger Out
  );
//***************************************************************************
//Execute Register
//***************************************************************************

  // PC Source
  pc_src u_pc_src(
    .Jump(JumpE),
    .Jumpr(JumprE),
    .Branch(BranchE),
    .br_taken(ALUResultE[0]),
    .br_predict(br_predictE),
    .PCSrc(PCSrcE),
    .mispredict(mispredictE)
  );

  // ALU
  alu u_alu(
    .clk(clk),
    .reset(reset),
    .SrcA(SrcAE),               // Source A
    .SrcB(SrcBE),               // Source B
    .ALUControl(ALUControlE),   // ALU Control
    .BusyE(BusyE),              // ALU Busy
    .ALUResult(ALUResultE)      // ALU Result
  );

  // SrcAE - Forwarding Mux
  mux3 u_SrcA(
    .d0(RD1E),
    .d1(ResultW),
    .d2(ProALUResultM),
    .s(ForwardAE),
    .y(SrcAE)
  );

  // SrcBE - Forwarding Mux
  mux3 u_SrcB0(
    .d0(RD2E),
    .d1(ResultW),
    .d2(ProALUResultM),
    .s(ForwardBE),
    .y(WriteDataE)
  );

  // SrcBE - Forward or Immediate
  mux2 u_SrcB1(
    .d0(WriteDataE),
    .d1(ImmExtE),
    .s(ALUSrcE),
    .y(SrcBE)
  );

  // PCTargetE
  adder u_pcimm(
    .opA(PCE),
    .opB(ImmExtE),
    .sub_en(1'b0),
    .sum(PCTargetE)
  );

//***************************************************************************
  // Vector Coprocessor Interface (Execute Stage)
  //***************************************************************************
  vicuna_wrapper u_vicuna_wrapper (
      .clk(clk),
      .reset(reset),
      .vector_req_E(vector_req_E),
      .instruction_E(InstrE),
      .rs1_data_E(SrcAE),      // Tapped AFTER ForwardAE mux (most recent data)
      .rs2_data_E(WriteDataE), // Tapped AFTER ForwardBE mux (most recent data)
      .vicuna_busy(vicuna_busy_E), 

      // ==========================================
      // NEW: MEMORY BUS PASS-THROUGH
      // ==========================================
      .v_mem_valid(v_mem_valid),
      .v_mem_we(v_mem_we),
      .v_mem_be(v_mem_be),
      .v_mem_addr(v_mem_addr),
      .v_mem_wdata(v_mem_wdata),
      .v_mem_ready(v_mem_ready),
      .v_mem_result_valid(v_mem_result_valid),
      .v_mem_rdata(v_mem_rdata),
      // ADD THESE TWO CONNECTIONS:
      .v_pending_load(v_pending_load),
      .v_pending_store(v_pending_store), 
      .v_xreg_we   (v_xreg_we),
      .v_xreg_rd   (v_xreg_rd),
      .v_xreg_data (v_xreg_data)
  );

  
//***************************************************************************
//Memory Register
//***************************************************************************
  memory_reg u_memory_reg(
    .clk(clk),
    .clr(FlushM),
    // Control Signals
    .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE),
    .MemWriteE(MemWriteE),
    .s_selE(s_selE),
    .l_selE(l_selE),
    .u_loadE(u_loadE),
    .ALUResultSrcE(ALUResultSrcE),
    .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),
    .MemWriteM(MemWriteM),
    .s_selM(s_selM),
    .l_selM(l_selM),
    .u_loadM(u_loadM),
    .ALUResultSrcM(ALUResultSrcM),
    // PC, Register Address, Data
    .ALUResultE(ALUResultE),
    .WriteDataE(WriteDataE),
    .PCTargetE(PCTargetE),
    .RdE(RdE),
    .PCPlus4E(PCPlus4E),
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    .PCTargetM(PCTargetM),
    .RdM(RdM),
    .PCPlus4M(PCPlus4M)
  );
//***************************************************************************
//Memory Register
//***************************************************************************

  // ALU Result
  mux3 u_alu_result(
    .d0(ALUResultM),
    .d1(PCPlus4M),
    .d2(PCTargetM),
    .s(ALUResultSrcM),
    .y(ProALUResultM)
  );

  assign MemWrite  = MemWriteM;
  assign byte_en   = byte_enM;
  assign ALUResult = ProALUResultM;
  assign WriteData = ProWriteDataM;
  store_unit u_store(
    .MemWrite(MemWriteM),       // Memory Write Enable
    .s_sel(s_selM),             // Store Select
    .b_sel(ProALUResultM[1:0]), // Byte Select
    .RawData(WriteDataM),       // RD2E from Register File or Forwarded Paths
    .byte_en(byte_enM),         // Byte Enable
    .WriteData(ProWriteDataM)   // To Data Memory
  );

//***************************************************************************
//Writeback Register
//***************************************************************************
  assign ReadDataM = ReadData;
  writeback_reg u_writeback_reg(
    .clk(clk),
    // Control Signals
    .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),
    .l_selM(l_selM),
    .u_loadM(u_loadM),
    .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW),
    .l_selW(l_selW),
    .u_loadW(u_loadW),
    // PC, Register Address, Data
    .ALUResultM(ProALUResultM),
    .ReadDataM(ReadDataM),
    .PCTargetM(PCTargetM),
    .RdM(RdM),
    .PCPlus4M(PCPlus4M),
    .ALUResultW(ALUResultW),
    .ReadDataW(ReadDataW),
    .PCTargetW(PCTargetW),
    .RdW(RdW),
    .PCPlus4W(PCPlus4W)
  );
//***************************************************************************
//Writeback Register
//***************************************************************************

  // Load Unit
  load_unit ins_load(
    .l_sel(l_selW),             // Load Select
    .bhw_sel(ALUResultW[1:0]),  // Byte / Half-word Select
    .u_load(u_loadW),           // Unsigned Load Enable
    .RawData(ReadDataW),        // RD from Data Memory
    .ReadData(ProReadDataW)     // To Register File
  );

  // Result
  mux4 u_result(
    .d0(ALUResultW),
    .d1(ProReadDataW),
    .d2(PCPlus4W),
    .d3(PCTargetW),
    .s(ResultSrcW),
    .y(ResultW)
  );

//***************************************************************************
//Hazard Unit
//***************************************************************************
  hazard_unit u_hazard_unit(
    .Rs1D(Rs1D),
    .Rs2D(Rs2D),
    .Rs1E(Rs1E),
    .Rs2E(Rs2E),
    .RdE(RdE),
//   Use this when predictor is disabled (Look inside file too).
//  .PCSrcE(PCSrcE),
    .mispredictE(mispredictE),
    .ResultSrcE(ResultSrcE),    // 01 for reading from data memory
    .BusyE(BusyE),              // ALU busy signal
    .RdM(RdM),
    .RegWriteM(RegWriteM),
    .RdW(RdW),
    .RegWriteW(RegWriteW),
    .StallF(StallF),
    .StallD(StallD),
    .FlushD(FlushD),
    .StallE(StallE),
    .FlushE(FlushE),
    .FlushM(FlushM),
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .vicuna_busy_E(vicuna_busy_E) // NEW: Coprocessor Busy Flag In
  );
//***************************************************************************
//Hazard Unit
//***************************************************************************

endmodule
