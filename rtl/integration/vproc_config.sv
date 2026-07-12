// Reconstructed by Sanit Parashar from Vicunas config.mk generation logic (vproc/vicuna)
// Vicuna does not ship this file statically -- it is normally auto-generated at build time
// License: Solderpad Hardware License v2.1 / Apache License 2.0 (same terms as Vicuna)

package vproc_config;
    import vproc_pkg::*;


    parameter vproc_pkg::vreg_type    VREG_TYPE                   = vproc_pkg::VREG_GENERIC;
    parameter int unsigned            VREG_W                      = 128;

    parameter int unsigned            VPORT_RD_CNT                = 2;
    parameter int unsigned            VPORT_RD_W   [VPORT_RD_CNT] = '{default: VREG_W};
    parameter int unsigned            VPORT_WR_CNT                = 1;
    parameter int unsigned            VPORT_WR_W   [VPORT_WR_CNT] = '{default: VREG_W};

    parameter int unsigned            PIPE_CNT                    = 1;
    parameter bit [vproc_pkg::UNIT_CNT-1:0] PIPE_UNITS [PIPE_CNT] = '{
        (vproc_pkg::UNIT_CNT'(1) << vproc_pkg::UNIT_LSU) |
        (vproc_pkg::UNIT_CNT'(1) << vproc_pkg::UNIT_ALU) |
        (vproc_pkg::UNIT_CNT'(1) << vproc_pkg::UNIT_MUL) |
        (vproc_pkg::UNIT_CNT'(1) << vproc_pkg::UNIT_SLD) |
        (vproc_pkg::UNIT_CNT'(1) << vproc_pkg::UNIT_ELEM)
    };
parameter int unsigned            PIPE_W           [PIPE_CNT] = '{32};
    parameter int unsigned            PIPE_VPORT_CNT   [PIPE_CNT] = '{1};
    parameter int unsigned            PIPE_VPORT_IDX   [PIPE_CNT] = '{1};
    parameter int unsigned            PIPE_VPORT_WR    [PIPE_CNT] = '{0};

    parameter int unsigned            VLSU_QUEUE_SZ               = 4;
    parameter bit [vproc_pkg::VLSU_FLAGS_W-1:0] VLSU_FLAGS        = '0;
    parameter vproc_pkg::mul_type     MUL_TYPE                    = vproc_pkg::MUL_GENERIC;

    parameter int unsigned            INSTR_QUEUE_SZ              = 2;
    parameter bit [vproc_pkg::BUF_FLAGS_W-1:0]  BUF_FLAGS         =
        (vproc_pkg::BUF_FLAGS_W'(1) << vproc_pkg::BUF_DEQUEUE) |
        (vproc_pkg::BUF_FLAGS_W'(1) << vproc_pkg::BUF_VREG_PEND);

endpackage
