# Optimization Journey

This document tracks the cycle-count evolution of the 256-element vector dot
product kernel across three development stages, from a pure scalar baseline
to the final CV-X-IF/Vicuna-accelerated implementation.

All results below are directly reproducible from the logs in `sim/logs/` and
the verified kernel source in `sw/kernels/`.

## Results Summary

| Stage | Description | Cycles | Speedup vs. Scalar | Result | Log |
|---|---|---|---|---|---|
| 1. Scalar baseline | RV32IM only, no vector coprocessor | 6944 | 1.00× | `0x0055D580` PASS | [`sim/logs/log_xrun_scalar_256ele_arr_dot.txt`](../sim/logs/log_xrun_scalar_256ele_arr_dot.txt) |
| 2. Vicuna integration (LMUL=1) | Vector load/multiply, manual `vslidedown`+`vadd` tree reduction | 4301 | 1.61× | `0x0055D580` PASS | [`sim/logs/log_xrun_vector_256ele_arr_dot.txt`](../sim/logs/log_xrun_vector_256ele_arr_dot.txt) |
| 3. Final optimized (LMUL=4) | 4x register grouping + hardware `vredsum.vs` reduction | **1916** | **3.62×** | `0x0055D580` PASS | [`sim/logs/log_xrun_vector_256ele_vredsum_lmul4.txt`](../sim/logs/log_xrun_vector_256ele_vredsum_lmul4.txt) |

**Final result: 3.62× cycle-count reduction** (6944 → 1916 cycles), verified
via Cadence Xcelium 25.03 cycle-accurate simulation, with the correct dot
product result (`0x0055D580` = 5,625,216 decimal) confirmed at every stage.

## What changed between stages

### Stage 1 → Stage 2: Adding vector acceleration
The scalar baseline computes the dot product using standard RV32IM
instructions — no coprocessor offload. Stage 2 introduces the Vicuna RVV
coprocessor via the CV-X-IF interface, using `LMUL=1` (4-element vector
groups) with a manual reduction: each partial sum is combined using explicit
`vslidedown.vi` + `vadd.vv` instruction pairs. This already yields a 1.61×
speedup, but each `vslidedown`/`vadd` pair requires a full CV-X-IF round trip
per reduction step — a real bottleneck.

### Stage 2 → Stage 3: Removing the reduction bottleneck
The final kernel makes two key changes:

1. **`LMUL=4`**: groups four vector registers into one logical operand,
   loading 16 elements per `vle32.v` instead of 4. This cuts the loop from
   64 iterations down to 16 — a 4× reduction in CV-X-IF issue events.
2. **`vredsum.vs`**: replaces the manual `vslidedown`+`vadd` reduction with
   a single hardware tree-reduction instruction inside Vicuna. This
   eliminates the repeated CV-X-IF boundary crossings that dominated Stage
   2's overhead, since the reduction now happens entirely inside the
   coprocessor before a single result crosses back to the scalar core.

Together, these two changes account for the additional 2.24× speedup
(4301 → 1916 cycles) beyond what Stage 2 alone achieved.

## Scope note: what's preserved vs. what isn't

This repository reflects the **final, working integration** (`rtl/`,
verified against Stage 3). The intermediate RTL configuration used to
produce the Stage 2 (4301-cycle) result was iterated on directly during
development — files like `vproc_config.sv`, `vicuna_wrapper.sv`, and
`control_unit.sv` were modified in place rather than preserved as separate,
independently buildable snapshots for each stage.

Stage 1 and Stage 2 are therefore documented here **via their simulation
logs and result values**, which are real, unedited Xcelium output — not
reconstructed after the fact. The Stage 3 kernel (`sw/kernels/kernel3_vector_lmul4_vredsum.s`)
has been independently verified instruction-for-instruction against the
actual `i_mem.hex` that produced the 1916-cycle result (see
[`sw/mem_images/i_mem.hex`](../sw/mem_images/i_mem.hex)).
