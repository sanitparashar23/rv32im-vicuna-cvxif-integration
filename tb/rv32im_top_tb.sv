// rv32im_top_tb.sv — Integration-level testbench
//
// Validates the full RV32IM + Vicuna CV-X-IF integrated system end-to-end.
// Note: this is NOT a standalone core-verification testbench. Both the
// Jeffrey Core RV32IM pipeline and the Vicuna RVV coprocessor are used
// as pre-verified, independently-tested upstream IP (see THIRD_PARTY_LICENSES.md).
// This testbench validates only the *integration*: CV-X-IF wiring, the
// shared memory arbiter in rv32im_top.sv, and end-to-end kernel execution.
//
// Verification is black-box: only the memory-mapped interface (DMEM/IMEM)
// is checked. Vicuna internal vector register state is not probed directly,
// consistent with its role as a coprocessor, not a standalone core.
//
// Author: Sanit Parashar

//
//  rv32im_top_tb.sv — 256-element Vector Dot Product Benchmark [FINAL FIX]
//
//  Algorithm : A[1..256]={1..256}, B[257..512]={1..256}
//  Result    : DMEM[0] = 1²+2²+...+256² = 5,625,216 = 0x0055D580
//
//  i_mem.hex algorithm:
//    Setup: vsetvli(VL=4), vmv.v.i v4,0  (acc), vsetvli x15,x0(VLMAX=4)
//    Loop (64 iters): vle32 v1,v2; vmul v3; vadd v4,v4,v3; ptr advance; bne
//    Reduce: vmv.x.s x11,v4; vslidedown 3x; vmv.x.s x12/x13/x14; add; sw
//
module rv32im_top_tb;

  reg clk   = 1;
  reg reset = 1;
  always #100 clk = ~clk;   // 200 ns period

  parameter int IMEM_SIZE_POW2 = 10;
  parameter int DMEM_SIZE_POW2 = 12;
  parameter int IMEM_BASE_ADDR = 32'h0000_0000;
  parameter int DMEM_BASE_ADDR = 32'h8000_0000;

  logic sim_done;
  time  sim_start_time;
  time  sim_end_time;

  assign sim_done = (u_DUT.u_d_mem.DMEM[0] != 32'h0);

  always_ff @(posedge clk) begin
    if (reset) begin
      sim_start_time <= 0;
      sim_end_time   <= 0;
    end else begin
      if (sim_start_time == 0)
        sim_start_time <= $time;
      if (sim_done && sim_end_time == 0) begin
        sim_end_time <= $time;
        $display("=======================================================");
        $display("[VECTOR TIMING] Result committed at  : %0t ns", $time);
        $display("[VECTOR TIMING] Value                : %08h  (expect 0055D580)",
                 u_DUT.u_d_mem.DMEM[0]);
        $display("[VECTOR TIMING] Cycles               : %0d",
                 ($time - sim_start_time) / 200);
        $display("=======================================================");
      end
    end
  end

  initial begin
    #1;
    $display("[IMEM] Loaded OK. IMEM[0]=%08h (expect 80000537)",
             u_DUT.u_i_mem.IMEM[0]);
  end

  integer file, i;

  initial begin
    $dumpfile("rv32im_top_tb.vcd");
    $dumpvars(0, rv32im_top_tb);

    repeat (10) @(posedge clk);
    reset <= 0;

    begin : timeout_block
      for (integer cyc = 0; cyc < 200000; cyc++) begin
        @(posedge clk);
        if (u_DUT.u_d_mem.DMEM[0] != 32'h0) begin
          repeat (10) @(posedge clk);
          disable timeout_block;
        end
      end
    end

    file = $fopen("d_mem_final.hex", "w");
    if (file == 0) begin $display("ERROR: cannot open d_mem_final.hex"); $finish; end
    for (i = 0; i < 520; i++)
      $fdisplay(file, "%08X", u_DUT.u_d_mem.DMEM[i]);
    $fclose(file);

    $display("=======================================================");
    $display("[BENCH SUMMARY] Result (DMEM[0]) : %08h", u_DUT.u_d_mem.DMEM[0]);
    $display("[BENCH SUMMARY] Expected         : 0055D580 (5,625,216 decimal)");
    if (u_DUT.u_d_mem.DMEM[0] == 32'h0055D580)
      $display("[BENCH SUMMARY] Status           : PASS");
    else
      $display("[BENCH SUMMARY] Status           : FAIL");
    $display("=======================================================");
    $finish;
  end

  rv32im_top #(
    .IMEM_SIZE_POW2(IMEM_SIZE_POW2),
    .DMEM_SIZE_POW2(DMEM_SIZE_POW2),
    .IMEM_BASE_ADDR(IMEM_BASE_ADDR),
    .DMEM_BASE_ADDR(DMEM_BASE_ADDR)
  ) u_DUT (
    .clk  (clk),
    .reset(reset)
  );

endmodule
