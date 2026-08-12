# Waveform Evidence

Screenshots from Cadence Xcelium's EPWave viewer, captured from the Stage 3
(LMUL=4, `vredsum.vs`) simulation run that produced the 1916-cycle PASS
result documented in [`../debug-notes.md`](../debug-notes.md) and
[`../optimization-journey.md`](../optimization-journey.md).

All timestamps below are directly cross-checked against
[`../../sim/logs/log_xrun_vector_256ele_vredsum_lmul4.txt`](../../sim/logs/log_xrun_vector_256ele_vredsum_lmul4.txt),
which reports the result committing at exactly `385400 ns`.

---

## `loop_steady_state.png`

Window: ~295,000-335,000 ns.

Shows the main loop in steady-state execution: `PC` cycling through the
loop body addresses (`0x34 -> 0x38 -> 0x40 -> 0x34`), `vector_req_E`
pulsing once per iteration to trigger CV-X-IF issue, `vicuna_busy` /
`vicuna_busy_E` toggling in sync with coprocessor activity, and
`v_mem_valid` firing as Vicuna's LSU walks through array A and B
(addresses visibly incrementing: `0x8000_0710 -> 0x8000_0350 ->
0x8000_0750 -> 0x8000_0390 ...`).

## `vredsum_a1_bypass_final_commit.png`

Window: ~384,600-387,000 ns. This is the centerpiece capture.

Shows the exact cycle the final `vredsum.vs v11, v0, v20` retires and the
scalar-register bypass (`v_xreg_we`) fires: `v_xreg_rd = 0xb` (register 11,
ABI name `a1`), `v_xreg_data = 0x0055D580` (the final dot-product result).
Immediately after, `WriteData = 0x0055D580` confirms the value that gets
committed to `DMEM[0]` via the closing `sw a1, 0(a0)`.

This single capture is the visual proof behind the Bug 3 writeup in
`debug-notes.md`: it shows Vicuna's reduction result being written directly
into the scalar register file, bypassing the vector register file read
that caused the original LMUL=1 kernel's race condition.

## `final_result_commit_1916cycles.png`

Window: ~385,000-386,400 ns (a slightly wider view of the same event above,
without the `v_xreg_*` signals visible).

Included alongside the bypass capture as a second, independent view of the
same commit event -- useful if a reader wants to see `PC`, `ALUResult`, and
`WriteData` without the added `v_xreg_*` signal rows.

## `vsetvli_xreg_bypass.png`

Window: ~2,300-5,500 ns, early in the program (before the main loop).

An incidental but useful find while capturing the above: the same
`v_xreg_we` bypass mechanism also fires here, with `v_xreg_rd = 0xf`
(register 15, ABI name `a5`) and `v_xreg_data = 0x0010` (16 decimal).
This corresponds to `vsetvli a5, zero, e32, m4` -- Vicuna computing the
actual vector length (`vl = 16`, consistent with `LMUL=4`, `VLEN=128`,
`SEW=32`) and returning it to the scalar core via the same scalar-bypass
path used later for the final reduction result. Confirms the bypass is a
general mechanism (any CV-X-IF result whose `rd` matches a scalar register
number gets routed this way), not something special-cased for the
reduction alone.
