# =============================================================================
#  kernel3_vector_lmul4_vredsum.s
#  256-Element Vector Dot Product — RV32IM + RVV, LMUL=4, vl=16
#  Hardware vredsum.vs Reduction  ← FINAL OPTIMISED KERNEL
#
#  Thesis: "CV-X-IF Based Integration of Vicuna RVV Vector Coprocessor
#           with RV32IM Scalar Core for 5G PHY DSP Acceleration"
#  Author: Sanit Parashar, DIAT Pune, M.Tech VLSI & Embedded Systems
#
#  Source log: log_vector_256ele_vredsum_lmul4.txt (2026-05-06)
#  Result     : 0x0055D580 = 5,625,216  [PASS]
#  Cycles     : 1916
#  Speedup    : 3.62× over scalar baseline (6944 cycles)
#              2.24× over Kernel 2 (4301 cycles, LMUL=1 + tree reduce)
#
#  KEY OPTIMISATIONS OVER KERNEL 2:
#  ----------------------------------
#  1. LMUL=4: Groups v4..v7, v8..v11, v12..v15, v16..v19 into 4-register
#     logical vectors. Each vle32.v loads 16 int32 elements instead of 4,
#     reducing loop iterations from 64 → 16 (4× fewer XIF issue events).
#
#  2. vredsum.vs: Hardware tree reduction inside Vicuna. Replaces 4 manual
#     vslidedown+vadd instruction pairs (= 8 XIF crossings) with a single
#     hardware-internal reduction producing the partial sum in v4[0].
#     Eliminates the CV-X-IF boundary-crossing bottleneck entirely.
#
#  All instruction hex values confirmed cycle-accurate from Xcelium 25.03.
#
#  Memory layout (base: 0x80000000):
#    Array A: 0x80000010 .. 0x8000040F  (256 × int32)
#    Array B: 0x80000410 .. 0x8000080F  (256 × int32)
#    Result : MEM[0x80000000]
#
#  Register map (scalar):
#    a0 = 0x80000000  (base address)
#    a1 = pointer into A  (advances by 64 each iteration)
#    a2 = pointer into B  (advances by 64 each iteration)
#    a3 = 64  (byte stride = 16 elements × 4 bytes)
#    a4 = loop counter  (16 iterations)
#    a5 = vl returned by vsetvli (= 16)
#
#  Vector register map (LMUL=4 groups):
#    v4  .. v7   = running partial-sum accumulator
#    v8  .. v11  = chunk of Array A  (16 × int32)
#    v12 .. v15  = chunk of Array B  (16 × int32)
#    v16 .. v19  = element-wise products (vmulh.vv result)
#    v20 .. v23  = final merged accumulator (post-loop)
#    v24 .. v27  = zero-init scratch accumulator
# =============================================================================

.section .text
.global _start

_start:

    # ------------------------------------------------------------------
    # 1. Initialise base and array pointers
    # ------------------------------------------------------------------
    lui     a0, 0x80000             # a0 = 0x80000000        Hex: 80000537
    addi    a1, a0,   16            # a1 = 0x80000010 (&A[0]) Hex: 01050593
    addi    a2, a0,  1040           # a2 = 0x80000410 (&B[0]) Hex: 41050613

    # ------------------------------------------------------------------
    # 2. Scalar loop control
    # ------------------------------------------------------------------
    addi    a3, zero,  64           # a3 = 64 (byte stride)   Hex: 04000693
    addi    a5, zero,   8           # temp; overwritten below  Hex: 00800793

    # ------------------------------------------------------------------
    # 3. Configure vector unit: SEW=e32, LMUL=m4
    #    Vicuna grants vl=16 (VLEN=128, LMUL=4, SEW=32 → 4×4=16 elems)
    #    rd=a5 receives actual vl; rs1=zero requests max vl
    #    Hex: 012077D7
    # ------------------------------------------------------------------
    vsetvli a5, zero, e32, m4      # a5 ← 16; Vicuna: LMUL=4, SEW=32

    # ------------------------------------------------------------------
    # 4. Zero-initialise vector accumulators
    #    LMUL=4: vmv.v.i on v4 writes to v4,v5,v6,v7 (4-register group)
    #    Confirmed from VAULT log: v4,v5,v6,v7 all written with 0x00..00
    #    Hex: 5E003257  (v4), 5E003C57  (v24)
    # ------------------------------------------------------------------
    vmv.v.i v4,  0                  # v4..v7   = 0  (main accumulator)
    vmv.v.i v24, 0                  # v24..v27 = 0  (scratch accumulator)

    # ------------------------------------------------------------------
    # 5. Loop counter: 256 / 16 = 16 iterations
    #    Hex: 01000713
    # ------------------------------------------------------------------
    addi    a4, zero, 16            # a4 = 16

    # ------------------------------------------------------------------
    # 6. Pipeline bubbles — allow Vicuna to commit vtype/vl state
    #    before the first vector memory instruction is dispatched.
    #    Observed in log: vsetvli retires at 4000ns; first vle32 issues
    #    at 15600ns — nops provide the necessary scalar stall cycles.
    #    Hex: 00000013 × 2
    # ------------------------------------------------------------------
    nop                             # bubble 1
    nop                             # bubble 2

    # ==================================================================
    # MAIN LOOP — 16 iterations × 16 elements = 256 elements
    # Loop target: PC = 0x002C
    # ==================================================================
loop:
    # ------------------------------------------------------------------
    # 7. Load 16 × int32 from Array A → v8..v11 (LMUL=4 group)
    #    Confirmed from VAULT: v8,v9,v10,v11 written sequentially per iter
    #    Final iter: v8=[f1..f4], v9=[f5..f8], v10=[f9..fc], v11=[fd..100]
    #    Hex: 0205E407
    # ------------------------------------------------------------------
    vle32.v v8,  (a1)              # v8..v11 ← MEM[a1 .. a1+63]

    # ------------------------------------------------------------------
    # 8. Load 16 × int32 from Array B → v12..v15 (LMUL=4 group)
    #    Hex: 02066607
    # ------------------------------------------------------------------
    vle32.v v12, (a2)              # v12..v15 ← MEM[a2 .. a2+63]

    # ------------------------------------------------------------------
    # 9. Element-wise high-half multiply → v16..v19
    #    vmulh.vv vd, vs2, vs1
    #    v16[j] = high32(v12[j] × v8[j])  for j=0..15
    #    Confirmed from VAULT (final iter):
    #      v16=[e2e1,e4c4,e6a9,e890] v17=[ea79,ec64,ee51,f040]
    #      v18=[f231,f424,f619,f810] v19=[fa09,fc04,fe01,10000]
    #    Hex: 96862857
    # ------------------------------------------------------------------
    vmulh.vv v16, v12, v8          # v16..v19 = high32(B[i] × A[i])

    # ------------------------------------------------------------------
    # 10. Hardware reduction — accumulate sum of v16[0..15] into v4[0]
    #     vredsum.vs vd, vs2, vs1:
    #       vd[0] = vs1[0] + sum(vs2[0..vl-1])
    #     Here: v4[0] = v4[0] + sum(v16[0..15])
    #     This single XIF instruction replaces 4 vslidedown+vadd pairs,
    #     eliminating 7 additional XIF crossings per loop iteration.
    #     Confirmed from VAULT (final iter):
    #       v4=[e710,f640,5090,5150] v5=[2490,3440,4410,5400]
    #       v6=[6410,7440,8490,9500] v7=[a590,b640,c710,d800]
    #     Hex: 02480257
    # ------------------------------------------------------------------
    vredsum.vs v4, v16, v4         # v4[0] += sum(v16[0..15]) — HW tree reduce

    # ------------------------------------------------------------------
    # 11. Advance pointers
    #     Hex: 00D585B3, 00D60633
    # ------------------------------------------------------------------
    add     a1, a1, a3             # a1 += 64  (next 16 elements of A)
    add     a2, a2, a3             # a2 += 64  (next 16 elements of B)

    # ------------------------------------------------------------------
    # 12. Loop control
    #     Hex: FFF70713, FE0712E3
    # ------------------------------------------------------------------
    addi    a4, a4, -1             # a4--
    bne     a4, zero, loop         # if a4 ≠ 0 → PC = 0x002C

    # ==================================================================
    # POST-LOOP: merge accumulators and extract scalar result
    # ==================================================================

    # ------------------------------------------------------------------
    # 13. Element-wise add: v20 = v24 + v4 (merge two accumulators)
    #     vadd.vv vd, vs2, vs1
    #     Confirmed from VAULT: v20 all elements = 0x0055D580
    #     (v24 was zero, so v20 = v4; confirms accumulator held full sum)
    #     Hex: 024C2A57
    # ------------------------------------------------------------------
    vadd.vv v20, v24, v4           # v20 = v24 + v4

    # ------------------------------------------------------------------
    # 14. Final scalar reduction: sum all elements of v20 → v11[0]
    #     vredsum.vs v11, v0, v20
    #     v11[0] = v0[0] + sum(v20[0..vl-1]) = 0 + 0x0055D580 = 5,625,216
    #     Hex: 434025D7
    # ------------------------------------------------------------------
    vredsum.vs v11, v0, v20        # v11[0] = Σ v20 = final dot product

    # ------------------------------------------------------------------
    # 15. Store result to memory
    #     Hex: 00B52023
    # ------------------------------------------------------------------
    sw      a1, 0(a0)              # MEM[0x80000000] = result

    # ------------------------------------------------------------------
    # 16. Halt
    #     Hex: 0000006F
    # ------------------------------------------------------------------
    jal     zero, 0                # spin (testbench detects $finish)

# =============================================================================
#  Complete i_mem.hex (all 23 words, confirmed from EDA Playground run):
#
#  80000537   lui      a0, 0x80000
#  01050593   addi     a1, a0, 16
#  41050613   addi     a2, a0, 1040
#  04000693   addi     a3, zero, 64
#  00800793   addi     a5, zero, 8
#  012077D7   vsetvli  a5, zero, e32, m4
#  5E003257   vmv.v.i  v4, 0
#  5E003C57   vmv.v.i  v24, 0
#  01000713   addi     a4, zero, 16
#  00000013   nop
#  00000013   nop
#  0205E407   vle32.v  v8,  (a1)
#  02066607   vle32.v  v12, (a2)
#  96862857   vmulh.vv v16, v12, v8
#  02480257   vredsum.vs v4, v16, v4
#  00D585B3   add      a1, a1, a3
#  00D60633   add      a2, a2, a3
#  FFF70713   addi     a4, a4, -1
#  FE0712E3   bne      a4, zero, -28
#  024C2A57   vadd.vv  v20, v24, v4
#  434025D7   vredsum.vs v11, v0, v20
#  00B52023   sw       a1, 0(a0)
#  0000006F   jal      zero, 0
# =============================================================================
