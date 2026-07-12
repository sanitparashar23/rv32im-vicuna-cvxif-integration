// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Modified by Sanit Parashar for RV32IM-Vicuna CV-X-IF integration (2026)
// See THIRD_PARTY_LICENSES.md for details on scope of changes


import my_pkg::*;

module control_unit
(
  input  opcode      op,           // Op Codes
  input  logic [2:0] funct3,       // Function 3 Field
  input  logic       funct7b0,     // Function 7 Field, bit-0
  input  logic       funct7b5,     // Function 7 Field, bit-5

  output logic       RegWrite,     // Register Write Enable
  output logic [1:0] ResultSrc,    // Result Select
  output logic       MemWrite,     // Memory Write Enable
  output logic [1:0] s_sel,        // Store Select
  output logic [1:0] l_sel,        // Load Select
  output logic       u_load,       // Unsigned Load Enable
  output logic       Jump,         // jal    Signal
  output logic       Jumpr,        // jalr   Signal
  output logic       Branch,       // branch Signal
  output logic [1:0] ALUResultSrc, // ALU Result Select
  output ALUOp       ALUControl,   // ALU Control
  output logic       ALUSrc,       // SrcB Select. 0: ForwardBE_out, 1: ImmExtE
  output imm_t       ImmSrc,        // Immediate Decoding
  output logic       vector_req_o  // NEW: Vector Coprocessor Trigger
);
  // --------------------------------------------------------
  // VECTOR COPROCESSOR TRIGGER
  // OP-V (Standard Vector): 7'b1010111 (V_TYPE)
  // LOAD-FP (Vector Load):  7'b0000111
  // STORE-FP (Vector Store): 7'b0100111
  // --------------------------------------------------------
  assign vector_req_o = (op == V_TYPE)    || 
                        (op == 7'b0000111) || 
                        (op == 7'b0100111);

  // Register Write Enable Logic (Zeroed during Vector ops to prevent corruption)
  assign RegWrite = ((op==R_TYPE) || (op==I_TYPE_a) || (op==I_TYPE_b) || (op==I_TYPE_c) || (op==U_TYPE_a) || (op==U_TYPE_b) || (op==J_TYPE)) & ~vector_req_o;
 

  // Result Source Selection Logic
  always_comb begin

    case(op)
      I_TYPE_a,
      J_TYPE   : ResultSrc = 2'b10; // PC + 4
      I_TYPE_b : ResultSrc = 2'b01; // RD from Data Memory
      U_TYPE_b : ResultSrc = 2'b11; // PC + ImmExt
      default  : ResultSrc = 2'b00; // ALUResult
    endcase

  end

  // Memory Write Enable logic (Zeroed during Vector ops to prevent corruption)
  assign MemWrite = (op==S_TYPE) & ~vector_req_o;

  // Store Select Logic
  always_comb begin

    s_sel = 2'b10;             // Store Word by default.

    if(op==S_TYPE) begin
      case(funct3[1:0])
        2'b00 : s_sel = 2'b00; // Store Byte
        2'b01 : s_sel = 2'b01; // Store Half-word
        2'b10 : s_sel = 2'b10; // Store Word
      default : s_sel = 2'b10; // Store Word
      endcase
    end

  end

  // Load Select Logic
  always_comb begin

    l_sel  = 2'b10;             // Load Word by default.
    u_load = 1'b1;              // Unsigned Load by default.

    if(op==I_TYPE_b) begin

      case(funct3)
        3'b000,
        3'b100 : l_sel = 2'b00; // Load Byte

        3'b001,
        3'b101 : l_sel = 2'b01; // Load Half-word

        3'b010 : l_sel = 2'b10; // Load Word
       default : l_sel = 2'b10; // Load Word
      endcase

      u_load = funct3[2];       // Unsigned Load

    end

  end

  // Jump/Branch Toggle
  always_comb begin

    Jump   = (op==J_TYPE);
    Jumpr  = (op==I_TYPE_a);
    Branch = (op==B_TYPE);

  end

  // ALU Result Source Selection Logic
  always_comb begin

    case(op)
      I_TYPE_a,
      J_TYPE   : ALUResultSrc = 2'b01; // PC + 4
      U_TYPE_b : ALUResultSrc = 2'b10; // PC + ImmExt
      default  : ALUResultSrc = 2'b00; // ALUResultM'
    endcase

  end

  // ALU Control Logic
  always_comb begin

    case(op)
      R_TYPE,
      I_TYPE_c : if((op==R_TYPE) & funct7b0) begin
                   case(funct3)
                     3'b000 : ALUControl = OP_MUL; 
                     3'b001 : ALUControl = OP_MULH;
                     3'b010 : ALUControl = OP_MULHSU;
                     3'b011 : ALUControl = OP_MULHU;
                     3'b100 : ALUControl = OP_DIV;
                     3'b101 : ALUControl = OP_DIVU;
                     3'b110 : ALUControl = OP_REM;
                     3'b111 : ALUControl = OP_REMU;
                    default : ALUControl = OP_INVAL;
                   endcase
                 end else begin
                   case(funct3)
                     3'b000 : ALUControl = (op==R_TYPE) & funct7b5 ? OP_SUB : OP_ADD; 
                     3'b001 : ALUControl = OP_SLL;
                     3'b010 : ALUControl = OP_LESS;
                     3'b011 : ALUControl = OP_LESSU;
                     3'b100 : ALUControl = OP_XOR;
                     3'b101 : ALUControl = funct7b5 ? OP_SRA : OP_SRL;
                     3'b110 : ALUControl = OP_OR;
                     3'b111 : ALUControl = OP_AND;
                    default : ALUControl = OP_INVAL;
                   endcase
                 end

      I_TYPE_a,
      I_TYPE_b,
      S_TYPE   : ALUControl = OP_ADD;

      B_TYPE   : case(funct3)
                   3'b000 : ALUControl = OP_EQ;
                   3'b001 : ALUControl = OP_NEQ;
                   3'b100 : ALUControl = OP_LESS;
                   3'b101 : ALUControl = OP_GEQ;
                   3'b110 : ALUControl = OP_LESSU;
                   3'b111 : ALUControl = OP_GEQU;
                  default : ALUControl = OP_INVAL;
                 endcase

      U_TYPE_a : ALUControl = OP_LUI;

      default  : ALUControl = OP_INVAL;
    endcase

  end

  // ALU SrcB Selection Logic
  assign ALUSrc = (op==I_TYPE_a) || (op==I_TYPE_b) || (op==I_TYPE_c) || (op==S_TYPE) || (op==U_TYPE_a);

  // Immediate Source Selection Logic
  always_comb begin

    case(op)
      I_TYPE_a,
      I_TYPE_b,
      I_TYPE_c  : ImmSrc = I_imm;

      S_TYPE    : ImmSrc = S_imm;

      B_TYPE    : ImmSrc = B_imm;

      U_TYPE_a,
      U_TYPE_b  : ImmSrc = U_imm;

      J_TYPE    : ImmSrc = J_imm;

      default   : ImmSrc = I_imm;
    endcase

  end

endmodule
