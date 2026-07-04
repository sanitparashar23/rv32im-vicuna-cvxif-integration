# Third-Party Licenses & Attributions

This repository integrates and builds upon open-source hardware components.
The table below documents the origin and license of each third-party component used.

## Components

| Component | Source | License | Location in this repo |
|---|---|---|---|
| RV32IM 5-stage scalar core | [jeffreyc-dev/rv32im-5stage-cpu](https://github.com/jeffreyc-dev/rv32im-5stage-cpu) | MIT License | `rtl/scalar_core/` |
| Vicuna RVV vector coprocessor | [vproc/vicuna](https://github.com/vproc/vicuna) | Solderpad Hardware License v2.1 (may alternatively be treated as Apache License 2.0, per Vicuna's license terms) | `rtl/vector_coproc/` |
| CV-X-IF interface specification | [OpenHW Group](https://github.com/openhwgroup/core-v-xif) | Referenced as an interface standard (no code copied directly; used to implement the coprocessor interface wiring in this repo) | `rtl/cvxif_wrapper/` |

## Diagrams

| Diagram | Source | Notes |
|---|---|---|
| `docs/diagrams/rv32im_5stage_microarch.png` | Adapted from Jeffrey Core project documentation ([jeffreyc-dev/rv32im-5stage-cpu](https://github.com/jeffreyc-dev/rv32im-5stage-cpu)) | Used for educational/reference purposes to illustrate the 5-stage scalar pipeline microarchitecture; not an original diagram created by this project's author |
| `docs/diagrams/vicuna_cvxif_microarch.png` | Adapted from Vicuna project documentation ([vproc/vicuna](https://github.com/vproc/vicuna)) | Used for educational/reference purposes to illustrate the CV-X-IF vector pipeline structure; not an original diagram created by this project's author |

## License Summary

- All **original work** in this repository (RTL integration/glue logic, CV-X-IF wrapper code written by the author, testbenches, synthesis scripts, documentation, and hand-assembled kernels) is licensed under the **MIT License** — see [`LICENSE`](./LICENSE).
- Files derived from or copied from **Jeffrey Core** retain their original **MIT License**.
- Files derived from or copied from **Vicuna** retain their original **Solderpad Hardware License v2.1 / Apache License 2.0**.
- Where third-party license notices exist in individual source files, those notices are preserved and take precedence over the repository-level LICENSE for that specific file.
