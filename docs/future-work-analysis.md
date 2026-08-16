# Future Work Analysis: Toward a Dual-Domain (eMBB + URLLC) Compute Node

This document is a working analysis, kept separate from the thesis
document itself. It reframes what this repository actually demonstrates,
and lays out a concrete, evidence-grounded path toward the dual-domain
(eMBB + URLLC) compute node originally scoped in the thesis's Phase 1
problem statement.

**Evidence standard used throughout:** claims are marked as one of three
types --
**[RTL-verified]** -- checked directly against this repo's source or logs,
**[literature-grounded]** -- backed by a cited external source,
or **[open question]** -- a real gap, explicitly flagged rather than guessed at.

---

## Reframing Phase 1: what this repository actually demonstrates

The 256-element vector dot-product kernel, its 3.62x cycle-count reduction,
and its 100 MHz synthesis closure are best understood as validating the
**CV-X-IF integration methodology** at a kernel size and density
representative of **eMBB-class** workloads (large FFTs, high-order MIMO
precoding, large transport block sizes) -- not as a direct demonstration
of the URLLC/DU use case originally scoped in the thesis's Phase 1
literature survey.

This is not a flaw in the work done -- the integration methodology itself
is domain-agnostic -- but the honest scope statement is: **this repository
validates the eMBB direction. The URLLC/DU direction requires the
additional work described below.**

---

## Why URLLC and eMBB place genuinely different demands on this compute node

**[literature-grounded]** 3GPP defines URLLC's target as 99.999%
reliability with end-to-end latency under 1 ms, for a typical packet size
of 32 bytes. This small-packet, latency-critical profile tends to use
conservative, low-order MIMO (few spatial layers) rather than the
large-panel massive-MIMO configurations more common in eMBB. A real
hardware precoder implementation in the literature describes its core
operation as a **"dot product" followed by a "combiner/adder"** stage --
structurally the same pattern already built and verified in this repo,
just operating on drastically smaller operand counts for low-layer-count
precoding.

**[RTL-verified]** Every CV-X-IF vector instruction in this design pays a
fixed issue/retire/writeback round-trip cost before useful work proceeds.
From `sim/logs/log_xrun_vector_256ele_vredsum_lmul4.txt`: `vsetvli` issues
at 3,600 ns and retires at 4,000 ns; the first real vector load does not
issue until 15,600 ns. That is roughly **78 cycles (at 100 MHz) of fixed
setup overhead** before a single array element is touched. For the
256-element kernel this repo demonstrates, that overhead is ~4% of total
runtime -- negligible. For a URLLC-scale kernel (e.g. a 2x2 or 4x4
precoding dot product, or a 32-byte transport block operation), that same
fixed cost would dominate total runtime, likely making native scalar
execution faster than offloading to Vicuna at all.

**Conclusion:** the eMBB and URLLC directions require different
architectural investments, not just "more of the same." eMBB benefits from
making large-kernel offload more efficient (chaining, wider utilization of
already-present ISA features). URLLC benefits from avoiding the offload
round-trip entirely for small kernels.

---

## Phase 2, eMBB track: closing the utilization gap on large kernels

### Capability already present in Vicuna but unused by the current kernel

**[RTL-verified]** Checked directly against `rtl/vector_coproc/vproc_lsu.sv`
and `rtl/vector_coproc/vproc_decoder.sv`:

- **Strided memory access** is already implemented. `vproc_lsu.sv`
  explicitly distinguishes `LSU_UNITSTRIDE` and `LSU_STRIDED` addressing
  modes with dedicated address-generation logic for each. The current
  kernel only uses unit-stride access (`vle32.v`/`vse32.v`).
- **Masked/predicated operations** are already implemented. `instr_masked`
  is decoded directly from instruction bit 25 in `vproc_decoder.sv`, with
  dedicated mask-load/store handling and `ALU_MASK_WRITE` mode support.
  The current kernel runs entirely unmasked (`vm=1` throughout, confirmed
  during the instruction-hex decode used to verify the `vmul`/`vmulh`
  discrepancy documented in `docs/debug-notes.md`).

**Practical implication:** a real near-term eMBB improvement does not
require new Vicuna hardware capability at all -- it requires a **new
kernel** that exercises capability already present, such as a masked
reduction (relevant to precoding across an active-layer subset) or
strided access (relevant to non-contiguous MIMO layer data in memory).

### Vector chaining -- open question, honestly flagged

**[open question]** A suggestion from a JRF at the author's institution
raised vector chaining (forwarding one vector operation's result directly
into a dependent operation without a full register-file round trip) as a
potential improvement. This was not investigated due to time constraints.
A search of `rtl/vector_coproc/vproc_core.sv` for chaining-related logic
returned no results, but this is inconclusive -- chaining support, if
present, would more likely live in `vproc_pipeline.sv`,
`vproc_unit_wrapper.sv`, or `vproc_queue.sv`, none of which have been
inspected for this. **This remains a genuinely open question**, not a
confirmed gap or a confirmed capability.

If chaining is absent and were added, the expected benefit would scale
*with* kernel size -- larger eMBB-class kernels (bigger FFTs, larger
matrices) would benefit more than the URLLC-class small kernels described
below, since chaining reduces the *marginal* cost of each additional
vector op in a longer sequence, not the fixed setup cost.

---

## Phase 2, URLLC track: a native small-kernel fast path

**[RTL-verified]** basis: the same 78-cycle/15,600 ns fixed CV-X-IF setup
overhead cited above. For URLLC-scale operations (small precoding
matrices, 32-byte transport block processing), this fixed cost is
proportionally dominant, unlike for the eMBB-scale kernel already
demonstrated.

**Proposed direction:** a small in-pipeline MAC/SIMD datapath added
directly to the scalar core's execute stage (`rtl/integration/rv32im.sv`)
-- e.g. a custom instruction, using RISC-V's reserved custom-opcode space,
performing a 2-4 element parallel multiply-accumulate without touching
CV-X-IF at all. This mirrors the design philosophy of commercial DSP-
capable scalar cores: Synopsys's ARC HS45D/HS47D processors
**[literature-grounded]** implement over 150 DSP instructions including
MAC and vector add/subtract directly in the scalar pipeline, reserving
their attached vector DSP engine (ARC VPX/VSPX family) for genuinely large
streaming workloads -- the same big/little amortization principle observed
empirically in the Cygnus comparison below.

This is real, non-trivial future RTL work: new decode logic, a new small
ALU/multiplier extension, and its own verification -- not a parameter
tweak. A concrete, data-driven crossover threshold (below which the
scalar fast path should be used instead of Vicuna offload) can be derived
directly from the ~78-cycle measured overhead once the fast path exists.

---

## Supporting analysis: scalar-core ALU/multiplier/divider tradeoffs

**[RTL-verified]** The measured critical path in `synth/reports/timing_with_mem.rpt`
is `u_cpu_u_pc/PC_reg[6]/CK -> u_cpu_u_pc/PC_reg[31]/D` -- the PC-generation
adder, not the RV32M multiplier. Cross-checked against the kernel source:
`sw/kernels/kernel3_vector_lmul4_vredsum.s` contains **zero** scalar `mul`,
`div`, or `rem` instructions. All MAC work is offloaded to Vicuna; the
scalar core's own multiplier is never exercised by this workload.

| Component | Impact on current workload | URLLC relevance | eMBB relevance |
|---|---|---|---|
| Carry-lookahead / parallel-prefix adder | **High** -- sits directly on the measured critical path | High -- every cycle's determinism depends on PC/branch resolution speed, and URLLC's fast HARQ/mini-slot decisions are control-flow-heavy | Moderate -- higher effective clock improves dispatch throughput, but eMBB tolerates more latency variance |
| Booth multiplier (RV32M) | **None measured** -- scalar multiplier unused by current kernel | Low -- URLLC control logic rarely needs heavy multiply; a variable-latency Booth multiplier can also hurt worst-case timing predictability, which cuts against URLLC's determinism requirement | Low, for the same reason as the current kernel -- MAC work is offloaded to Vicuna, not the scalar multiplier |
| Integer divider | Unused by current kernel | Risk if kept on a deadline-critical path -- an unbounded-latency divider is a tail-latency risk URLLC cannot tolerate unless bounded/pipelined | Occasionally used in control-plane bookkeeping (MCS/code-rate calculations), not hot-path |

**[literature-grounded]** Synopsys treats the integer divider as an
*optional, configurable* block in the ARC HS45D/HS47D DSP-oriented core
family, not a mandatory fixture -- real industry precedent for scoping the
divider's inclusion to actual workload needs rather than keeping it by
default.

**Recommendation:** prioritize the CLA/adder upgrade -- it is the only
item with a directly measured impact, and it helps both domains. Defer the
Booth multiplier upgrade until a workload that actually exercises scalar
multiply is added to this repo. Treat the divider as a scope decision
(narrow DSP-dispatch-only role favors removal; broader control-plane role
favors keeping it, ideally with bounded/pipelined latency for URLLC
compatibility).

---

## Comparative grounding: real silicon at smaller nodes

**[literature-grounded]** Cygnus (Jain, Grubb, Zhao et al., UC Berkeley,
2025 VLSI Symposium) is a real, taped-out, RVV 1.0-compliant octa-core
vector processor for DSP, fabricated in Intel16 (16nm).

| | This work | Cygnus little core | Cygnus big core | Ara | AraXL |
|---|---|---|---|---|---|
| Process node | 45nm (academic GPDK) | 16nm (real tapeout) | 16nm | 22nm FD-SOI | 22nm FD-SOI |
| VLEN | 128b | **128b** (exact match) | 512b | lane-based | lane-based |
| Scalar frontend | RV32IM, single-issue, 5-stage | RV64GCV, dual-issue, 7-stage | RV64GCV, dual-issue, 7-stage | RV64GC (paired) | RV64GC (paired) |
| Vector issue model | Tightly-coupled CV-X-IF (blocking round-trip) | Decoupled access-execute (independent load/store + compute sequencers) | Decoupled access-execute | 16-lane parallel | up to 64-lane parallel |
| Max clock achieved | 100 MHz (closed, verified) | 1.01 GHz (measured silicon, shmoo-verified) | 1.01 GHz | 1.2 GHz | 1.15 GHz |
| Core count | 1 | 4 (of 8 total) | 4 (of 8 total) | 1 | 1 (many-lane) |

**Honest interpretation:** even a professionally taped-out chip at
roughly a third of this design's node, with a more sophisticated dual-issue
decoupled-execute frontend, purpose-built for exactly this design's vector
length (Cygnus little core, VLEN=128b), still only reaches ~1 GHz -- not an
order of magnitude beyond that. A realistic frequency-scaling ceiling for
this design's single-core architecture, even at a much smaller node, is
therefore closer to ~10x than to the 20-50x a naive "smaller node = 
proportionally faster" assumption might suggest.

More importantly: Cygnus does not get its DSP throughput primarily from
that 1 GHz clock. It gets there from **8 parallel cores with a big/little
utilization strategy and decoupled access-execute** -- 90% average
utilization across GEMM/CONV kernels, 414 GOPS/W (INT8) peak energy
efficiency. This design's own tightly-coupled, single-core, blocking
CV-X-IF integration is exactly the architectural pattern Cygnus's DAE
design was built to move away from. The bottleneck this repo's own
debug-notes independently diagnosed (every boundary-crossing costs a full
round-trip) is the same bottleneck a funded, team-built, professionally
fabricated chip identified and solved differently. That is a legitimate
point of validation for the diagnosis, not evidence the diagnosis was
wrong -- but it does mean the honest framing of this repo's contribution
is **"validated the integration methodology and correctly diagnosed the
real bottleneck,"** not **"delivered a performance-competitive per-node
result."** Those are different, both true, claims.

---

## Summary: recommended priority order

1. **CLA/parallel-prefix adder** -- highest confidence, directly measured
   impact, helps both domains.
2. **New kernel(s) exercising existing Vicuna capability** (masking,
   strided access) -- low RTL risk, immediate eMBB-relevant gain, no new
   hardware required.
3. **URLLC native small-kernel fast path** -- highest long-term value for
   the originally-scoped URLLC/DU use case, but genuinely new RTL work
   requiring its own design and verification cycle.
4. **Vector chaining investigation** -- resolve the open question (inspect
   `vproc_pipeline.sv`/`vproc_unit_wrapper.sv`) before committing design
   effort either way.
5. **Booth multiplier, divider removal** -- lowest priority given current
   workload evidence; revisit if/when a control-plane-oriented kernel is
   added to this repository.
