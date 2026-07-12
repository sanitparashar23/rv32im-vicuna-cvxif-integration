// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module mux3 #(parameter WIDTH = 32)
(
  input  logic [WIDTH-1:0] d0, d1, d2, // Data In
  input  logic       [1:0] s,          // Select
  output logic [WIDTH-1:0] y           // Data Out
);

  assign y = s[1] ? d2 :
             s[0] ? d1 :
                    d0 ;

endmodule
