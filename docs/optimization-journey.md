# Optimization Journey

This document tracks the cycle-count evolution of the 256-element vector dot
product kernel across three development stages, from a pure scalar baseline
to the final CV-X-IF/Vicuna-accelerated implementation.

All results below are directly reproducible from the logs in `sim/logs/` and
the verified kernel source in `sw/kernels/`.

## Results Summary

| Stage | Description | Cycles | Speedup vs. Scalar | Result | Log |
|---|---|---|---|---|---|
| 1. Scalar baseline | RV32IM only, no vector coprocessor | 6944 | 1.00x | `0x0055D580` PASS | [`sim/logs/log_xrun_scalar_256ele_arr_dot.txt`](../sim/logs/log_xrun_scalar_256ele_arr_dot.txt) |
| 2. Vicuna integration (LMUL=1) | Vector load/multiply/accumulate, one-time final tree reduction | 4301 | 1.61x | `0x0055D580` PASS | [`sim/logs/log_xrun_vector_256ele_arr_dot.txt`](../sim/logs/log_xrun_vector_256ele_arr_dot.txt) |
| 3. Final optimized (LMUL=4) | 4x register grouping + per-iteration hardware `vredsum.vs` | **1916** | **3.62x** | `0x0055D580` PASS | [`sim/logs/log_xrun_vector_256ele_vredsum_lmul4.txt`](../sim/logs/log_xrun_vector_256ele_vredsum_lmul4.txt) |

**Final result: 3.62x cycle-count reduction** (6944 -> 1916 cycles), verified
via Cadence Xcelium 25.03 cycle-accurate simulation, with the correct dot
product result (`0x0055D580` = 5,625,216 decimal) confirmed at every stage.

## What changed between stages

The explanation below is verified directly against the `VICUNA ISSUE` /
`VICUNA VAULT` instruction trace in the Stage 2 and Stage 3 logs, not
reconstructed from memory.

### Stage 1 -> Stage 2: Adding vector acceleration

The scalar baseline computes the dot product using standard RV32IM
instructions only, with no coprocessor offload.

Stage 2 introduces the Vicuna RVV coprocessor via CV-X-IF, using `LMUL=1`
(4-element vector groups). The per-iteration instruction pattern, confirmed
from the log and repeated 64 times (256 elements / 4 per group):

1. `vle32.v` — load 4 elements of array A
2. `vle32.v` — load 4 elements of array B
3. `vmulh.vv` — elementwise multiply
4. `vadd.vv` — accumulate the product into a running 4-wide sum

Each of these four steps is a separate CV-X-IF issue from the RV32IM scalar
core. Critically, step 4 (`vadd.vv`) is re-issued from RV32IM on **every one
of the 64 iterations** — this repeated round-trip across the CV-X-IF
boundary, just to perform the running accumulation, is the main cost driver
in this stage.

After all 64 iterations complete, a **one-time** final reduction collapses
the 4-wide accumulator down to a single scalar value, using four alternating
`vslidedown`/`vadd` instruction pairs (visible at the end of the Stage 2 log,
timestamps ~839400-861000 ns). This final collapse happens once, not per
iteration — the per-iteration cost is entirely the repeated `vadd.vv` step
above.

This stage already yields a 1.61x speedup over the scalar baseline.

### Stage 2 -> Stage 3: Removing the per-iteration reduction bottleneck

The final kernel makes two key changes, both confirmed from the Stage 3 log:

1. **`LMUL=4`**: groups four vector registers into one logical operand,
   loading 16 elements per `vle32.v` instead of 4. This cuts the loop from
   64 iterations down to 16 — a 4x reduction in the number of CV-X-IF issue
   events for the load/multiply steps alone.

2. **`vredsum.vs` replacing the per-iteration `vadd.vv`**: instead of issuing
   a separate accumulate instruction from RV32IM on every iteration, the
   final kernel issues a single `vredsum.vs` per iteration. This instruction
   performs the equivalent of load + reduce + accumulate entirely inside
   Vicuna, folding the 16 newly-computed products directly into the running
   scalar-in-a-vector accumulator (`v4[0]`) in one hardware operation. The
   scalar core no longer has to separately issue an accumulate step at all.

Together, these two changes mean Stage 3 issues far fewer CV-X-IF
instructions overall (16 iterations x 3 vector instructions, versus 64
iterations x 4 in Stage 2) and eliminates the specific per-iteration
accumulate round-trip that dominated Stage 2's overhead. This accounts for
the additional 2.24x speedup (4301 -> 1916 cycles) beyond what Stage 2 alone
achieved.

A one-time final step is still required in Stage 3 too — a `vadd.vv` merging
two scratch accumulators, followed by a single closing `vredsum.vs` — but,
as in Stage 2, this happens once at the very end, not per iteration.

## Scope note: what's preserved vs. what isn't

This repository reflects the **final, working integration** (`rtl/`,
verified against Stage 3). The intermediate RTL configuration used to
produce the Stage 2 (4301-cycle) result was iterated on directly during
development — files like `vproc_config.sv`, `vicuna_wrapper.sv`, and
`control_unit.sv` were modified in place rather than preserved as separate,
independently buildable snapshots for each stage.

Stage 1 and Stage 2 are therefore documented here **via their simulation
logs and result values**, which are real, unedited Xcelium output — not
reconstructed after the fact. The Stage 3 kernel
(`sw/kernels/kernel3_vector_lmul4_vredsum.s`) has been independently
verified instruction-for-instruction against the actual `i_mem.hex` that
produced the 1916-cycle result (see
[`sw/mem_images/i_mem.hex`](../sw/mem_images/i_mem.hex)).
