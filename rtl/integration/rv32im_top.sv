// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Modified by Sanit Parashar for RV32IM-Vicuna CV-X-IF integration (2026)
// See THIRD_PARTY_LICENSES.md for details on scope of changes

module rv32im_top #(
  parameter int IMEM_SIZE_POW2 = 10,            // 2^10 = 1   KB Instruction Memory
  parameter int DMEM_SIZE_POW2 =  12,            // 2^9  = 512 B  Data Memory
  parameter int IMEM_BASE_ADDR = 32'h0000_0000, // IMEM starts at 0x0000_0000
  parameter int DMEM_BASE_ADDR = 32'h8000_0000  // DMEM starts at 0x8000_0000
)(
  input logic clk,
  input logic reset
);

  // Instruction Memory Ports
  logic [31:0] Instr;
  logic [31:0] PC;

  // Scalar Data Memory Ports
  logic [31:0] ReadData;
  logic        MemWrite;
  logic  [3:0] byte_en;
  logic [31:0] ALUResult;
  logic [31:0] WriteData;

  // =========================================================================
  // COPROCESSOR MEMORY WIRES
  // =========================================================================
  logic        vicuna_busy;
  logic        v_mem_valid;
  logic        v_mem_we;
  logic [3:0]  v_mem_be;
  logic [31:0] v_mem_addr;
  logic [31:0] v_mem_wdata;
  wire         v_pending_load;
  wire         v_pending_store;

  // v_mem_ready: assert only when Vicuna has an active request.
  // Since d_mem read is combinational, it is always "ready" in 0 cycles.
  // Tying ready=valid is the correct handshake for a zero-latency slave.
  logic v_mem_ready;
  assign v_mem_ready = v_mem_valid;

  // =========================================================================
  // SHARED MEMORY ARBITER
  //
  //  Priority: Vicuna wins whenever v_mem_valid=1.
  //  Scalar core is gated by:
  //    ~v_mem_valid    : real-time guard (catches the exact request cycle)
  //    ~v_pending_store: freeze scalar reads+writes during any vector store
  //    ~(v_pending_load & MemWrite): no scalar writes during a vector load
  // =========================================================================
  logic [31:0] shared_addr;
  logic [31:0] shared_wdata;
  logic        shared_we;
  logic  [3:0] shared_be;

  wire scalar_dmem_en = ~v_mem_valid
                      & ~v_pending_store
                      & ~(v_pending_load & MemWrite);

  always_comb begin
    if (v_mem_valid) begin
      shared_we    = v_mem_we;
      shared_be    = v_mem_be;
      shared_addr  = v_mem_addr;
      shared_wdata = v_mem_wdata;
    end else begin
      shared_we    = MemWrite & scalar_dmem_en;
      shared_be    = byte_en;
      shared_addr  = ALUResult;
      shared_wdata = WriteData;
    end
  end

  // =========================================================================
  // CPU
  // =========================================================================
  rv32im u_cpu (
    .clk       (clk),
    .reset     (reset),
    .Instr     (Instr),
    .PC        (PC),
    .ReadData  (ReadData),
    .MemWrite  (MemWrite),
    .byte_en   (byte_en),
    .ALUResult (ALUResult),
    .WriteData (WriteData),
    // Coprocessor ports
    .vicuna_busy        (vicuna_busy),
    .v_mem_valid        (v_mem_valid),
    .v_mem_we           (v_mem_we),
    .v_mem_be           (v_mem_be),
    .v_mem_addr         (v_mem_addr),
    .v_mem_wdata        (v_mem_wdata),
    .v_mem_ready        (v_mem_ready),
    // v_mem_result_valid: wrapper ignores this internally; must be driven to avoid floating
    .v_mem_result_valid(1'b0),
    .v_mem_rdata        (ReadData),
    .v_pending_load     (v_pending_load),
    .v_pending_store    (v_pending_store)
  );

  // =========================================================================
  // INSTRUCTION MEMORY
  // =========================================================================
  i_mem #(
    .SIZE_POW2(IMEM_SIZE_POW2),
    .BASE_ADDR(IMEM_BASE_ADDR)
  ) u_i_mem (
    .A (PC),
    .RD(Instr)
  );

  // =========================================================================
  // DATA MEMORY
  //   .clk(~clk): d_mem always_ff fires on posedge of ~clk = NEGEDGE of sys_clk.
  //   Writes settle at negedge N; Vicuna's mem_result_valid fires at posedge N+1.
  //   Reads are combinational (async); captured in wrapper at posedge N.
  // =========================================================================
  d_mem #(
    .SIZE_POW2(DMEM_SIZE_POW2),
    .BASE_ADDR(DMEM_BASE_ADDR)
  ) u_d_mem (
    .clk    (~clk),
    .WE     (shared_we),
    .byte_en(shared_be),
    .A      (shared_addr),
    .WD     (shared_wdata),
    .RD     (ReadData)
  );

endmodule
