// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module store_unit
(
  input  logic        MemWrite, // Memory Write Enable
  input  logic  [1:0] s_sel,    // Store Select
  input  logic  [1:0] b_sel,    // Byte Select
  input  logic [31:0] RawData,  // RD2E from Register File or Forwarded Paths
  output logic  [3:0] byte_en,  // Byte Enable
  output logic [31:0] WriteData // To Data Memory
);

  always_comb begin

    case(s_sel)
      2'b00 : WriteData = {4{RawData[7:0]}};  // Store Byte
      2'b01 : WriteData = {2{RawData[15:0]}}; // Store Half-word
      2'b10 : WriteData = RawData;            // Store Word
    default : WriteData = RawData;            // Default
    endcase

  end

  // Store Select Logic
  always_comb begin

    byte_en = 4'b1111;

    if (MemWrite) begin

      case(s_sel)
        2'b00 : begin // Store Byte
                  case(b_sel)
                    2'b00 : byte_en = 4'b0001;
                    2'b01 : byte_en = 4'b0010;
                    2'b10 : byte_en = 4'b0100;
                    2'b11 : byte_en = 4'b1000;
                  default : byte_en = 4'b0001;
                  endcase
                end
        2'b01 : begin // Store Half-word
                  case(b_sel[1])
                    1'b0  : byte_en = 4'b0011;
                    1'b1  : byte_en = 4'b1100;
                  default : byte_en = 4'b0011;
                  endcase
                end
        2'b10 : // Store Word
                  byte_en = 4'b1111;
      default : // Store Word
                  byte_en = 4'b1111;
      endcase

    end

  end

endmodule 
