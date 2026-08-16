# 5G PHY Scaling Estimate

**Purpose and scope.** This document is a literature-grounded,
order-of-magnitude *estimate*, not a silicon-verified claim. It exists to
answer a specific, honest question: given this design's real, measured
performance at 45nm/100MHz, what would it take -- and is it plausible --
for this architecture to meet real 5G PHY throughput demands at a smaller
process node? The distinction matters: this kernel is a **MAC-heavy compute
pattern representative of 5G PHY workloads** (FFT, precoding, and
equalization all reduce to dense MAC operations), not a demonstration that
this design **meets 5G PHY real-time requirements** as built. Every number
below is either taken directly from this repo's own verified results, or
cited from an external source with the source stated.

---

## Step 1: A concrete target -- MACs/sec for DU-side precoding (corrected for O-RAN Split 7.2x scope)

**Revision note:** an earlier version of this step used FFT operation
count as the target workload. This was inconsistent with this project's
own stated scope: under O-RAN Split 7.2x (as claimed in the thesis),
FFT/CP-removal is performed at the RU (low-PHY), not the DU. A DU-hosted
compute node receives frequency-domain IQ samples directly and never
performs FFT/iFFT itself. The corrected target workload below is
**precoding**, a real DU-side (high-PHY) operation, and one that is
structurally identical to the dot-product-plus-reduction pattern already
built and verified in this repo -- confirmed directly from a published
hardware precoder implementation, which describes its core datapath as a
"dot product" stage followed by a "combiner/adder" stage.

**[literature-grounded, standard 3GPP numerology]** Using the same NR
numerology mu=1 (30 kHz SCS) as before: OFDM symbol duration (including
cyclic prefix) is approximately 35.7 us. A 100 MHz channel bandwidth at
this numerology corresponds to approximately 273 resource blocks (12
subcarriers each), i.e. roughly 3,276 subcarriers -- this is an
approximate figure from standard NR resource-block tables, not corrected
for exact guard-band allocation, and is used here as a reasonable
order-of-magnitude basis, not an exact spec figure.

**Two representative precoding configurations** (both grounded in
published precoder hardware implementations, which use matrix sizes
(16x8), (32x8), and (64x8) multiplied against an (8x1) data vector per
subcarrier):

**Typical commercial eMBB configuration** (modest antenna/layer count,
representative of common non-massive-MIMO gNB deployments): an 8x4
precoding matrix (8 antenna ports, 4 spatial layers) applied per
subcarrier = 8 x 4 = 32 MACs/subcarrier.

  Per OFDM symbol: 3,276 subcarriers x 32 MACs = ~104,800 MACs
  Target throughput: 104,800 / 35.7 us = **~2.94 x 10^9 MACs/sec (~2.9 GMAC/s)**

**Massive-MIMO upper bound** (per the cited literature's 64x8 example,
64 antenna elements, 8 layers): 64 x 8 = 512 MACs/subcarrier.

  Per OFDM symbol: 3,276 subcarriers x 512 MACs = ~1,677,300 MACs
  Target throughput: 1,677,300 / 35.7 us = **~4.7 x 10^10 MACs/sec (~47 GMAC/s)**

**This document uses the typical/modest case (~2.9 GMAC/s) as the primary
target**, since it is more representative of common commercial eMBB
deployments than a massive-MIMO research configuration. The massive-MIMO
figure is retained as a cited upper bound for context.

*Caveat: this is a simplified, single-antenna-chain-equivalent,
precoding-only estimate. It does not include equalization, channel
estimation, or demodulation, all of which add further MAC load at the DU.
It is a target for total system throughput at this function, not
necessarily for a single compute node in isolation.*

**Note on robustness:** this corrected, precoding-based target
(~2.9 GMAC/s) is close in order of magnitude to the earlier (now retracted)
FFT-based estimate (~2.75 GMAC/s) -- see Step 3 for why this coincidence
does not change this document's overall conclusion.

---

## Step 2: This design's actual, measured throughput (fact, not estimate)

**[RTL-verified]** From `sim/logs/log_xrun_vector_256ele_vredsum_lmul4.txt`:
the 256-element dot product (256 real MAC-equivalent operations: 256
multiplies via `vmul.vv`, reduced via `vredsum.vs`) completes in 1916
cycles at 100 MHz.

Achievable throughput = 256 MACs / 1916 cycles x 100 x 10^6 cycles/sec
= **~13.4 x 10^6 MACs/sec (13.4 MMAC/s)**

---

## Step 3: The gap, stated plainly

Target (Step 1, corrected, precoding-based): ~2.9 x 10^9 MACs/sec
Achieved (Step 2): ~13.4 x 10^6 MACs/sec

**Gap: approximately 216x.**

This is a large, honest gap, and it should not be minimized. It is the
single most important number in this document. Notably, this gap is
essentially unchanged from the earlier FFT-based estimate (~205x) despite
using a completely different, architecturally-correct representative
workload -- this robustness across two independently-derived targets is
itself evidence that Step 5's conclusion (the gap is architectural, not
specific to which DU function is chosen as the benchmark) is not an
artifact of the particular workload picked.

---

## Step 4: Does node scaling close this gap? No -- not close.

**[literature-grounded]** Per the Cygnus/Ara comparison in
`future-work-analysis.md`, real taped-out RISC-V vector silicon at smaller
nodes (16nm Cygnus, 22nm Ara/AraXL) achieves clock frequencies in the
~1.0-1.2 GHz range for architecturally similar single-core designs -- 
roughly a **10x** improvement over this design's measured 100 MHz, not
20-50x. This design's own critical path (`u_cpu_u_pc`, the PC-generation
adder, per `synth/reports/timing_with_mem.rpt`) is a ripple-carry-style
structural bottleneck that a smaller node alone does not fix -- closing it
requires the CLA/parallel-prefix adder change described in
`future-work-analysis.md`, independent of node.

Applying a generous 10x frequency-scaling factor to Step 2's achieved
throughput: ~13.4 MMAC/s x 10 = ~134 MMAC/s.

**Remaining gap after node scaling: ~2.9 GMAC/s / 134 MMAC/s =
still roughly 22x short.**

---

## Step 5: What actually closes a 200x-class gap (and what doesn't)

A 200x+-class gap is not the kind of gap a single core, at any realistic node,
closes through frequency alone. This is confirmed by every real-world
reference point examined:

- **Cygnus** closes its throughput gap through **8 parallel cores** with a
  big/little utilization strategy and decoupled access-execute, not
  through raw clock speed (90% average utilization across GEMM/CONV,
  414 GOPS/W peak).
- **Dedicated fixed-function 5G baseband ASICs** (e.g. a 65nm FFT
  processor at 250 MHz, a companion 65nm MIMO detection ASIC at 625 MHz,
  both from published baseband processing literature) achieve required
  throughput through **dedicated parallel datapaths**, at clock frequencies
  even lower than what this design already achieves at 45nm -- reinforcing
  that frequency is not the dominant lever in real deployed systems.
- **FPGA/adaptive SoC** approaches (e.g. Xilinx RFSoC-based Telco
  Accelerator Cards used in real O-RAN DUs) and **GPU/software-defined**
  approaches (e.g. NVIDIA Aerial-class architectures) both scale through
  reconfigurable or massive core-count parallelism, not per-core clock.

**Honest conclusion:** this design's single-core, tightly-coupled CV-X-IF
architecture is not the right shape to close a gap of this size through
node shrinkage or clock-frequency projection alone, no matter how
aggressively the adder/multiplier critical path is optimized. The gap is
architectural (parallelism), not primarily a clock-frequency problem. This
directly supports, rather than contradicts, the future-work direction
already proposed: multi-core / decoupled-execute evolution (see
`future-work-analysis.md`) is the credible path to closing a gap of this
magnitude, not a smaller PDK by itself.

---

## What would need to happen to make this claim rigorous

1. Re-synthesize at an actual smaller node (not GPDK45nm) to replace the
   Cygnus/Ara-derived 10x scaling assumption with a real, measured number
   for this specific RTL.
2. Implement the CLA/parallel-prefix adder change to remove the current
   ripple-carry critical path, independent of node.
3. Extend from single-core to a multi-core or decoupled access-execute
   architecture (per `future-work-analysis.md`), since Step 5 shows this
   is the dominant lever real systems actually use.
4. Refine the Step 1 target using a full system-level MAC budget (MIMO
   layers, equalization, precoding included), not FFT alone, for a more
   complete and conservative target figure.

---

## References

- 3GPP NR numerology and frame structure (standard OFDM symbol duration
  scaling by subcarrier spacing).
- Jain, V., Grubb, D., Zhao, J., et al. "Cygnus: A 1 GHz Heterogeneous
  Octa-Core RISC-V Vector Processor for DSP." 2025 Symposium on VLSI
  Technology and Circuits.
- Cavalcante, M. et al. "Ara: A 1-GHz+ Scalable and Energy-Efficient RISC-V
  Vector Processor with Multiprecision Floating-Point Support in 22-nm
  FD-SOI." IEEE TVLSI, 2020.
- Perotti, M. et al. (AraXL). IEEE TCAS-II, 2023.
- Synopsys ARC HS45D/HS47D processor product literature (configurable
  integer divider, DSP instruction set).
- Published 65nm baseband FFT/MIMO-detection ASIC literature (in-memory
  computing baseband processing).
- Precoder hardware implementation literature describing precoding as a
  dot-product-and-combiner datapath (arXiv:2501.00366).
- 3GPP URLLC reliability/latency/packet-size targets (99.999% reliability,
  <1ms latency, 32-byte typical packet size), as cited across multiple
  URLLC-focused publications (arXiv:2007.04784, arXiv:2106.09322).
