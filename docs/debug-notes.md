# Vicuna CV-X-IF Integration — Debugging Notes

**Project:** M.Tech Thesis — "CV-X-IF Based Integration of Vicuna RVV Vector
Coprocessor with RV32IM Scalar Core for 5G PHY DSP Acceleration"
**Author:** Sanit Parashar, DIAT Pune
**Tool:** Cadence Xcelium 25.03
**Kernel:** 256-element integer dot product, A . B = sum(A[i] * B[i]), i=0..255
**Expected result:** `0x0055D580` = 5,625,216 decimal

This document is verified against the actual RTL in `rtl/integration/` and
`rtl/vector_coproc/`, and against the simulation logs in `sim/logs/`, not
reconstructed from memory alone. Where a claim could not be independently
checked against a surviving artifact, it is marked as such.

---

## Final Results at a Glance

| Stage | Description | Cycles | Speedup | Status |
|---|---|---|---|---|
| 1 -- Scalar | RV32IM only, 256 iterations x 1 element | 6944 | 1.00x | PASS |
| 2 -- Vector LMUL=1 | Vicuna via CV-X-IF, vl=4, tree reduction | 4301 | 1.61x | PASS |
| 3 -- Vector LMUL=4 | Vicuna via CV-X-IF, vl=16, `vredsum.vs` | **1916** | **3.62x** | **PASS** |

Full derivation of these numbers is in [`optimization-journey.md`](optimization-journey.md).

---

## Architecture Context

The integration links Jeffrey Core (a pipelined RV32IM scalar processor) to
the Vicuna RVV coprocessor over the CV-X-IF (Core-V eXtension Interface)
protocol. The scalar core decodes standard RVV opcodes -- `OP-V`
(`7'b1010111`), `LOAD-FP` (`7'b0000111`), `STORE-FP` (`7'b0100111`) -- by
setting a `vector_req_o` signal in `control_unit.sv`, which gates
`RegWrite`/`MemWrite` with its inverse so vector instructions are not
executed by the scalar pipeline itself (verified: `rtl/integration/control_unit.sv`,
lines 28-54).

Instructions are forwarded to Vicuna over the CV-X-IF issue channel; Vicuna
owns execution, memory access (via its own LSU), and writeback. Every
boundary-crossing between the scalar core and Vicuna costs a full CV-X-IF
handshake round-trip -- this is the central cost driver across all three
kernels, and every bug below ultimately traces back to something going
wrong at that boundary.

---

## Note: `vmul` vs `vmulh` -- a correction to earlier documentation drafts

Earlier drafts of this document (and the kernel `.s` file's own inline
comments) referred to the multiply instruction as `vmulh.vv` ("high-half
multiply"). Decoding the actual instruction hex against the RVV `funct6`
encoding table shows this is incorrect:

- Stage 2's multiply (`9620a1d7`) decodes to `funct6=100101`
- Stage 3's multiply (`96862857`) decodes to `funct6=100101`

Per the RVV spec, `funct6=100101` is **`VMUL`** (low 32 bits of the
product), not `VMULH` (`100111`). Both kernels actually execute `vmul.vv`.
This does not affect correctness for the dataset used here -- the products
fit within 32 bits, so the low-half and high-half results are numerically
equivalent -- but the mnemonic in the source comments and in earlier
documentation was wrong and has been corrected here.

---

## Debugging Session

### Bug 1: Undriven CV-X-IF response fields causing X-propagation into Vicuna's LSU

**Symptom:** Simulation stalled after one memory element. The first
`vle32.v` load fetched only one word then hung. DMEM result = `0x00000000`.

**Root cause:** The `vicuna_wrapper.sv` instantiation of Vicuna's CV-X-IF
memory response port left three fields undriven: `exc` (exception flag),
`exccode` (exception code), `dbg` (debug). In SystemVerilog, undriven logic
defaults to `X`. Vicuna's LSU internally checks `exc` to determine whether a
memory transaction completed successfully; an `X` on `exc` resolves
indeterminately, so Vicuna treated the first element's transaction as
incomplete and halted issue of subsequent loads.

**Fix -- verified present in `rtl/integration/vicuna_wrapper.sv`, lines 178-180:**
```systemverilog
assign xif.mem_resp.exc     = 1'b0;
assign xif.mem_resp.exccode = 6'b0;
assign xif.mem_resp.dbg     = 1'b0;
```

---

### Bug 2: Incorrect `d_mem.hex` layout -- B array pointer mismatch

**Symptom:** All 64 iterations executed and Vicuna computed something, but
the result was wrong -- the accumulator grew each iteration but did not
match the expected value.

**Root cause:** The data memory file had array A occupying more words than
intended, pushing array B's actual start address one word later than where
the pointer arithmetic in the kernel expected it. Every B load ended up
reading A data instead.

**Fix:** Rewrote `d_mem.hex` so array A and array B are tightly packed at
the addresses the kernel's pointer arithmetic actually computes.

*Note: the specific historical hex layout that exhibited this bug was not
preserved as a separate file (only the final, corrected memory images in
`sw/mem_images/` survive), so the addresses above are reported from the
author's direct recollection of the debugging session rather than
independently verified against a surviving artifact. The current
`d_mem.sv` (word-indexed via `$readmemh`, verified in
`rtl/scalar_core/d_mem.sv`) is structurally consistent with this class of
bug being possible whenever the hex file layout and pointer arithmetic
disagree.*

---

### Bug 3: The `vredsum.vs` race in the LMUL=1 kernel, and why the LMUL=4 kernel doesn't hit it

This is the most involved bug in the integration, and its resolution
directly explains the architectural difference between the Stage 2 and
Stage 3 kernels.

**Original approach (Stage 2, first attempt):** Use `vredsum.vs` to collapse
the 4-lane accumulator to a scalar, then immediately store it.

**Symptom:** The loop completed correctly -- the accumulator's per-lane
values were correct and summed to the right answer -- but the final
memory result was `0x00000000`. `[BENCH SUMMARY]` showed FAIL.

**Root cause:** `vredsum.vs` has a multi-cycle completion latency inside
Vicuna. The instruction immediately following it (a vector store, `vse32.v`,
reading the reduction's destination vector register) issued before the
reduction had actually committed its result to the **vector register
file**. The CV-X-IF issue-ready handshake stalls the scalar core's next
*issue*, but does not by itself guarantee the vector regfile has been
updated in time for a vector-domain read that follows immediately.

**Abandoned in favor of:** a pure-vector `vslidedown.vi` + `vadd.vv` tree
reduction (4 pairs, collapsing the 4-lane accumulator manually), which
naturally serializes through Vicuna's `x_issue_ready` handshake because
each `vslidedown`/`vadd` is itself a full CV-X-IF transaction that must wait
for the prior one to clear. This became the Stage 2 kernel that produced
the 4301-cycle PASS result.

**Stage 3's different, better solution -- verified in RTL:**

Rather than avoiding `vredsum.vs`, the Stage 3 kernel uses it directly for
both the per-iteration accumulate and the final collapse, and it works
correctly. The reason it works here but not in the original Stage 2 attempt
is a genuine hardware feature, not luck: `rv32im.sv` implements a **scalar
register writeback bypass** from Vicuna, verified at lines 92-94, 216, and
221-222:

```systemverilog
logic        v_xreg_we;
logic [4:0]  v_xreg_rd;
logic [31:0] v_xreg_data;
...
.WE3(RegWriteW | v_xreg_we),
.A3 (v_xreg_we ? v_xreg_rd   : RdW),
.WD3(v_xreg_we ? v_xreg_data : ResultW)
```

driven from `vicuna_wrapper.sv`, lines 187-189:
```systemverilog
assign v_xreg_we   = xif.result_valid & xif.result_ready & xif.result.we;
assign v_xreg_rd   = xif.result.rd;
assign v_xreg_data = xif.result.data[31:0];
```

When `vredsum.vs v11, v0, v20` retires, its destination register number
(`rd=11`) coincides with the RISC-V GPR number for `a1` (`x11`). CV-X-IF's
result-write signals fire this bypass path, writing the reduction result
**directly into the scalar register file** at that position -- overwriting
whatever `a1` held before (in this kernel, the final incremented array-A
pointer value). By the time the closing `sw a1, 0(a0)` executes, `a1` no
longer holds the old pointer; it holds the reduction result, written
through this scalar bypass.

**This is why the two situations differ:** the failed Stage 2 attempt used
a *vector* store (`vse32.v`) reading the destination from the *vector*
register file, which the scalar bypass does nothing for. The working
Stage 3 kernel uses a *scalar* store (`sw`) reading from the *scalar*
register file, which the bypass keeps correctly up to date. Same
instruction (`vredsum.vs`), same underlying multi-cycle latency -- the
difference is which register file the following instruction reads from.

---

### Bug 4: `vproc_config.sv` / `vproc_core.sv` port-count mismatch (elaboration-time array-size error)

**Symptom:** During experimentation with a dual-port Vicuna configuration
(`PIPE_VPORT_CNT=2`), Xcelium raised a `BADBSE` elaboration error, and an
earlier attempt to work around it left the simulation stalling after the
first `vmv.v.i` with no vector instructions issuing.

**Root cause:** Xcelium 25.03 rejected an array-literal construction that
Verilator (the simulator these open-source cores are more commonly
developed against) accepts. Specifically, a `localparam` array indexed as
`[PIPE_VPORT_CNT[i]]` with a trailing pattern that worked under Verilator's
looser parsing caused a base/size mismatch error under Xcelium's stricter
elaboration.

**Fix -- verified present in `rtl/integration/vproc_core.sv`, lines 915-919,
and self-documented in the code itself:**
```systemverilog
// Xcelium-compatible: PIPE_VPORT_CNT=2, so array has 2 elements.
// No trailing apostrophe after closing brace (that caused BADBSE error).
// localparam int unsigned PIPE_VPORT_W[2] = '{...};  <- original attempt, commented out
localparam int unsigned PIPE_VPORT_W[1] = '{VPORT_RD_W[PIPE_VPORT_IDX[i]]};
```

The working configuration keeps `PIPE_VPORT_CNT=1` (single read port),
confirmed in `rtl/integration/vproc_config.sv`.

---

## Lessons Learned -- CV-X-IF Hazard Model

This integration revealed hazard classes that the CV-X-IF protocol does
**not** handle automatically in this wrapper implementation:

1. **Vector-register-read-after-reduction hazard:** a vector-domain
   instruction (e.g. `vse32.v`) reading the destination of a just-issued
   `vredsum.vs` can read stale data if it issues before the reduction's
   multi-cycle completion has updated the vector register file. The
   CV-X-IF issue-ready handshake serializes *issue*, not necessarily the
   underlying register file update. Workaround used here: route the final
   result through the scalar register file (via the `v_xreg_we` bypass)
   rather than reading it back from the vector domain.

2. **Vector-store-to-scalar-load hazard:** a scalar `lw` issued immediately
   after a Vicuna vector store to the same address can read stale DMEM
   data, since the scalar pipeline does not stall for a pending Vicuna
   store to complete.

3. **Scalar bypass is register-number-coincidental, not general-purpose:**
   the `v_xreg_we` mechanism writes to whichever scalar register number
   matches the vector instruction's `rd` field. This kernel benefits from
   it because `v11`'s register number happens to equal `a1`'s (`x11`) --
   it is not a generic "move vector result to any scalar register"
   instruction, and kernel authors need to choose destination register
   numbers deliberately to use this path.

---

## File Reference

| File | Purpose |
|---|---|
| `sw/kernels/kernel3_vector_lmul4_vredsum.s` | LMUL=4 optimised kernel, thesis result -- verified instruction-for-instruction against `sw/mem_images/i_mem.hex` |
| `sim/logs/log_xrun_scalar_256ele_arr_dot.txt` | Stage 1 log -- `0x0055D580` PASS, 6944 cycles |
| `sim/logs/log_xrun_vector_256ele_arr_dot.txt` | Stage 2 log -- `0x0055D580` PASS, 4301 cycles |
| `sim/logs/log_xrun_vector_256ele_vredsum_lmul4.txt` | Stage 3 log -- `0x0055D580` PASS, 1916 cycles |
| `rtl/integration/control_unit.sv` | `vector_req_o` decode (Bug context) |
| `rtl/integration/vicuna_wrapper.sv` | CV-X-IF bridge -- Bug 1 fix, `v_xreg_we` bypass source (Bug 3) |
| `rtl/integration/rv32im.sv` | Scalar pipeline, `v_xreg_we` bypass mux (Bug 3) |
| `rtl/integration/vproc_core.sv` | Bug 4 fix, self-documented in code comments |
| `rtl/integration/vproc_config.sv` | `PIPE_VPORT_CNT=1` working configuration (Bug 4) |
| `rtl/scalar_core/d_mem.sv` | Word-indexed memory model (Bug 2 context) |
