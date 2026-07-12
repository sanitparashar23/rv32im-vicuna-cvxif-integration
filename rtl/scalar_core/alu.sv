// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


import my_pkg::*;

module alu
(
  input  logic        clk,        // Clock
  input  logic        reset,      // Reset
  input  logic [31:0] SrcA,       // Source A
  input  logic [31:0] SrcB,       // Source B
  input  ALUOp        ALUControl, // ALU Control
  output logic        BusyE,      // ALU Busy
  output logic [31:0] ALUResult   // ALU Result
);

  logic [31:0] adder_out, shift_out, and_out, or_out, xor_out;
  logic        sub_en, v, c, n, z;
  logic        s_mode, a_en;

  logic [63:0] multiplier_out/*, multiplier_out2*/;
  logic [31:0] quotient_out, remainder_out/*, quotient_out2, remainder_out2*/;
  logic  [1:0] m_sign_sel;
  logic        d_sign_sel;
  logic        mul_op, div_op, mul_v, div_v;

  // Short to Zero when using single-cycle mul/div units
  assign BusyE = reset ? 1'b0 : (mul_op & !mul_v) | (div_op & !div_v);

  adder u_add(
    .opA(SrcA),
    .opB(SrcB),
    .sub_en(sub_en),
    .sum(adder_out),
    .overflow(v),
    .carry(c),
    .negative(n),
    .zero(z)
  );

  barrel_shifter u_shift(
    .data_in(SrcA),
    .shift_amount(SrcB[4:0]),
    .shift_mode(s_mode),      // 0: Left, 1: Right
    .arithmetic_en(a_en),     // 0: No Sign, 1: Preserve Sign
    .data_out(shift_out)
  );
/*
  multiplier_1c u_mul_1c(
    .opA(SrcA),
    .opB(SrcB),
    .sign_sel(m_sign_sel),    // 00: S/S, 01: S/U, 10: U/U
    .product(multiplier_out2)
  );
*/
  multiplier_16c u_mul_16c(
    .clk(clk),
    .reset(reset),
    .enable(mul_op),
    .opA(SrcA),
    .opB(SrcB),
    .sign_sel(m_sign_sel),    // 00: S/S, 01: S/U, 10: U/U
    .product(multiplier_out),
    .done(mul_v)
  );
/*
  divider_1c u_div_1c(
    .numA(SrcA),
    .denB(SrcB),
    .sign_sel(d_sign_sel),    // 0: S/S, 1: U/U
    .quotient(quotient_out2),
    .remainder(remainder_out2)
  );
*/
  divider_32c u_div_32c(
    .clk(clk),
    .reset(reset),
    .enable(div_op),
    .sign_sel(d_sign_sel),    // 0: S/S, 1: U/U
    .numA(SrcA),
    .denB(SrcB),
    .done(div_v),
    .quotient(quotient_out),
    .remainder(remainder_out)
  );

  always_comb begin

    sub_en = (ALUControl==OP_SUB)  ||
             (ALUControl==OP_EQ)   || (ALUControl==OP_NEQ)   ||
             (ALUControl==OP_LESS) || (ALUControl==OP_LESSU) ||
             (ALUControl==OP_GEQ)  || (ALUControl==OP_GEQU);     //  0: Addition by default, 1: Subtraction

    s_mode = (ALUControl==OP_SRL)  || (ALUControl==OP_SRA);      //  0: Left by default, 1: Right Shift

    a_en   = (ALUControl==OP_SRA);                               //  0: No Sign by default, 1: Preserve Sign

    mul_op = (ALUControl==OP_MUL)    || (ALUControl==OP_MULH) ||
             (ALUControl==OP_MULHSU) || (ALUControl==OP_MULHU);  //  0: NaM, 1: Mul Op

    div_op = (ALUControl==OP_DIV)    || (ALUControl==OP_DIVU) ||
             (ALUControl==OP_REM)    || (ALUControl==OP_REMU);   //  0: NaD, 1: Div Op

    m_sign_sel = (ALUControl==OP_MULHSU) ? 2'b01 :               // 01: Signed/Unsigned
                 (ALUControl==OP_MULHU)  ? 2'b10 :               // 10: Unsigned/Unsigned
                                           2'b00 ;               // 00: Signed/Signed by default

    d_sign_sel = (ALUControl==OP_DIVU) || (ALUControl==OP_REMU); //  0: Signed/Signed by default, 1: Unsigned/Unsigned

    and_out = SrcA & SrcB;
    or_out  = SrcA | SrcB;
    xor_out = SrcA ^ SrcB;

    case(ALUControl)
      // jalr, addi, add, sub
      // lb, lh, lw, lbu, lhu, sb, sh, sw
      // SrcA + SrcB
      // SrcA + ~SrcB + 1
      OP_ADD,
      OP_SUB     : ALUResult = adder_out;

      // beq
      // SrcA == SrcB
      OP_EQ      : ALUResult = z;

      // bne
      // SrcA != SrcB
      OP_NEQ     : ALUResult = !z;

      // blt, slti, slt
      // $signed(SrcA) < $signed(SrcB)
      OP_LESS    : ALUResult = n ^ v;

      // bltu, sltiu, sltu
      // $unsigned(SrcA) < $unsigned(SrcB)
      OP_LESSU   : ALUResult = !c;

      // bge
      // $signed(SrcA) >= $signed(SrcB)
      OP_GEQ     : ALUResult = !(n ^ v);

      // bgeu
      // $unsigned(SrcA) >= $unsigned(SrcB)
      OP_GEQU    : ALUResult = c;

      // andi, and
      // SrcA & SrcB
      OP_AND     : ALUResult = and_out;

      // ori, or
      // SrcA | SrcB
      OP_OR      : ALUResult = or_out;

      // xori, xor
      // SrcA ^ SrcB
      OP_XOR     : ALUResult = xor_out;

      // slli, sll, srli, srl, srai, sra
      // SrcA << SrcB
      // SrcA >> SrcB
      // $signed(SrcA) >>> SrcB
      OP_SLL,
      OP_SRL,
      OP_SRA     : ALUResult = shift_out;

      // lui
      // SrcB
      OP_LUI     : ALUResult = SrcB;

      // mul
      // $signed(SrcA) * $signed(SrcB)
      OP_MUL     : ALUResult = multiplier_out[31:0];

      // mulh, mulhsu, mulhu
      // $signed(SrcA) * $signed(SrcB)
      // $signed(SrcA) * $unsigned(SrcB)
      // $unsigned(SrcA) * $unsigned(SrcB)
      OP_MULH,
      OP_MULHSU,
      OP_MULHU   : ALUResult = multiplier_out[63:32];

      // div, divu
      // $signed(SrcA) / $signed(SrcB)
      // $unsigned(SrcA) / $unsigned(SrcB)
      OP_DIV,
      OP_DIVU    : ALUResult = quotient_out;

      // rem, remu
      // $signed(SrcA) % $signed(SrcB)
      // $unsigned(SrcA) % $unsigned(SrcB)
      OP_REM,
      OP_REMU    : ALUResult = remainder_out;

      // Invalid opcode
      OP_INVAL   : ALUResult = adder_out;
      default    : ALUResult = adder_out;
    endcase

  end

endmodule
