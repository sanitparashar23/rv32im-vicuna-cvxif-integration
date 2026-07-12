// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module barrel_shifter
(
  input  logic [31:0] data_in,       // Data
  input  logic  [4:0] shift_amount,  // Shift Amount
  input  logic        shift_mode,    // Shift Mode; 0: Left Shift, 1: Right Shift
  input  logic        arithmetic_en, // Sign Preservation Enable; 0: No Sign, 1: Preserve Sign

  output logic [31:0] data_out       // Result
);

  always_comb begin

    case({shift_mode,arithmetic_en})
      // Logical Left Shift
      2'b00,
      2'b01 : data_out = data_in << shift_amount;
      // Logical Right Shift
      2'b10 : data_out = data_in >> shift_amount;
      // Arithmetic Right Shift
      2'b11 : data_out = $signed(data_in) >>> shift_amount;
      // Logical Left Shift by default
    default : data_out = data_in << shift_amount;
    endcase

  end

endmodule
