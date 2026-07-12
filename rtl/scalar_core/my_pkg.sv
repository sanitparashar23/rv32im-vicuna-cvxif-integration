// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


package my_pkg;

  typedef enum logic [6:0] {
    R_TYPE   = 7'b0110011,   // ADD - AND, MUL - REMU
    I_TYPE_a = 7'b1100111,   // JALR
    I_TYPE_b = 7'b0000011,   // LB - LHU
    I_TYPE_c = 7'b0010011,   // ADDI - SRAI
    S_TYPE   = 7'b0100011,   // SB - SW
    B_TYPE   = 7'b1100011,   // BEQ - BGEU
    U_TYPE_a = 7'b0110111,   // LUI
    U_TYPE_b = 7'b0010111,   // AUIPC
    J_TYPE   = 7'b1101111,    // JAL
    V_TYPE = 7'b1010111       // VECTOR
  } opcode;

  typedef enum logic [4:0] {
    OP_ADD    = 5'h00,
    OP_SUB    = 5'h01,
    OP_EQ     = 5'h02,
    OP_NEQ    = 5'h03,
    OP_LESS   = 5'h04,
    OP_LESSU  = 5'h05,
    OP_GEQ    = 5'h06,
    OP_GEQU   = 5'h07,
    OP_AND    = 5'h08,
    OP_OR     = 5'h09,
    OP_XOR    = 5'h0A,
    OP_SLL    = 5'h0B,
    OP_SRL    = 5'h0C,
    OP_SRA    = 5'h0D,
    OP_LUI    = 5'h0E,
    OP_MUL    = 5'h0F,
    OP_MULH   = 5'h10,
    OP_MULHSU = 5'h11,
    OP_MULHU  = 5'h12,
    OP_DIV    = 5'h13,
    OP_DIVU   = 5'h14,
    OP_REM    = 5'h15,
    OP_REMU   = 5'h16,
    OP_INVAL  = 5'h17
  } ALUOp;

  typedef enum logic [2:0] {
    I_imm = 3'h0,
    S_imm = 3'h1,
    B_imm = 3'h2,
    U_imm = 3'h3,
    J_imm = 3'h4
  } imm_t;

endpackage
