// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module load_unit
(
  input  logic  [1:0] l_sel,   // Load Select
  input  logic  [1:0] bhw_sel, // Byte / Half-word Select
  input  logic        u_load,  // Unsigned Load Enable
  input  logic [31:0] RawData, // RD from Data Memory
  output logic [31:0] ReadData // To Register File
);

  always_comb begin

    case(l_sel)
      // Load Byte
      2'b00 : begin
                case(bhw_sel)
                  2'b00 : ReadData[7:0] = RawData[ 7: 0];  // Load Byte 0
                  2'b01 : ReadData[7:0] = RawData[15: 8];  // Load Byte 1
                  2'b10 : ReadData[7:0] = RawData[23:16];  // Load Byte 2
                  2'b11 : ReadData[7:0] = RawData[31:24];  // Load Byte 3
                default : ReadData[7:0] = RawData[ 7: 0];  // Default
                endcase

                ReadData[31:8] = u_load ? 24'b0 : {24{RawData[7]}};
              end
      // Load Half-word
      2'b01 : begin
                case(bhw_sel[1])
                  1'b0 : ReadData[15:0] = RawData[15: 0];  // Load Half-word 0
                  1'b1 : ReadData[15:0] = RawData[31:16];  // Load Half-word 1
               default : ReadData[15:0] = RawData[15: 0];  // Default
                endcase

                ReadData[31:16] = u_load ? 16'b0 : {16{RawData[15]}};
              end
      // Load Word
      2'b10 : ReadData = RawData;
      // Default
    default : ReadData = RawData;
    endcase

  end

endmodule
