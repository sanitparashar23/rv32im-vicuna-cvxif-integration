// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module mux2 #(parameter WIDTH = 32)
(
  input  logic [WIDTH-1:0] d0, d1, // Data In
  input  logic             s,      // Select
  output logic [WIDTH-1:0] y       // Data Out
);

  assign y = s ? d1 :
                 d0 ;

endmodule
