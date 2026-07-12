// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module mux4 #(parameter WIDTH = 32)
(
  input  logic [WIDTH-1:0] d0, d1, d2, d3, // Data In
  input  logic       [1:0] s,              // Select
  output logic [WIDTH-1:0] y               // Data Out
);

  assign y = (s==2'b11) ? d3 :
             (s==2'b10) ? d2 :
             (s==2'b01) ? d1 :
                          d0 ;

endmodule
