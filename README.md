# rv32im-vicuna-cvxif-integration
RTL integration of the Vicuna RVV vector coprocessor with a custom RV32IM scalar core using the CV-X-IF interface (Open HW Group), targeting DSP-style vector dot-product acceleration. Achieves 3.62× cycle reduction on a 256-element kernel, synthesized at 100MHz on GPDK45nm.
