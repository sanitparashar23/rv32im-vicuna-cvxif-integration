// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module multiplier_16c (
    input  logic        clk,
    input  logic        reset,    // synchronous reset
    input  logic        enable,   // start when high and unit idle (pulse is fine)
    input  logic  [1:0] sign_sel, // Sign Selection
    input  logic [31:0] opA,      // multiplicand
    input  logic [31:0] opB,      // multiplier
    output logic        done,     // one-cycle pulse when result valid
    output logic [63:0] product
);

    // State
    logic [31:0] ACC;       // accumulator
    logic [31:0] Q;         // multiplier
    logic  [1:0] C;         // top carry bits
    logic [31:0] M;         // multiplicand
    logic  [4:0] count;
    logic        busy;

    // Combinational signals
    logic [33:0] acc_ext;   // ACC extended
    logic [33:0] m_ext;     // M extended
    logic [33:0] addend;
    logic [33:0] sum34;
    logic  [1:0] q_low;
    logic [65:0] Ptmp;
    logic [65:0] Pshift;

    logic [31:0] newA, newB;
    logic        sign;
    logic [63:0] result;

  always_comb begin

    case(sign_sel)
      // mul,mulh
      2'b00 : begin
                newA = opA[31] ? ~opA + 1'b1 : opA;
                newB = opB[31] ? ~opB + 1'b1 : opB;
                sign = opA[31] ^ opB[31];
              end
      // mulhsu
      2'b01 : begin
                newA = opA[31] ? ~opA + 1'b1 : opA;
                newB = opB;
                sign = opA[31];
              end
      // mulhu
      2'b10 : begin
                newA = opA;
                newB = opB;
                sign = 1'b0;
              end
      // signed/signed by default
    default : begin
                newA = opA[31] ? ~opA + 1'b1 : opA;
                newB = opB[31] ? ~opB + 1'b1 : opB;
                sign = opA[31] ^ opB[31];
              end
    endcase

      product = sign ? ~result + 1'b1 : result;

  end

    // ------------------------------------------------------------
    // Combinational datapath
    // ------------------------------------------------------------
    always_comb begin
        // Extend ACC and M to 34 bits (no bit-selects)
        acc_ext = {2'b00, ACC};
        m_ext   = {2'b00, M};

        // Extract Q[1:0] WITHOUT bit-select:
        q_low = { Q[1], Q[0] };   // this is allowed

        // Radix-4 selection
        case (q_low)
            2'b00: addend = 34'd0;
            2'b01: addend = m_ext;
            2'b10: addend = m_ext << 1;
            2'b11: addend = m_ext + (m_ext << 1);
        endcase

        sum34 = acc_ext + addend;

        // Build 66-bit Ptmp = {C, sum34, Q}
        Ptmp = { C, sum34, Q };

        // Shift right by 2 (OK: Icarus allows shifts)
        Pshift = Ptmp >> 2;
    end

    // ------------------------------------------------------------
    // Sequential state machine
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset | !enable) begin
            ACC   <= 0;
            Q     <= 0;
            C     <= 0;
            M     <= 0;
            count <= 0;
            busy  <= 0;
            done  <= 0;
            result <= 0;
        end else begin
            done <= 0;

            if (!busy) begin
                if (enable) begin
                    // Start multiplication
                    M     <= newA;
                    ACC   <= 32'd0;
                    Q     <= newB;
                    C     <= 2'b00;
                    count <= 5'd16;
                    busy  <= 1'b1;
                end
            end
            else begin
                // Update state after shift
                {C, ACC, Q} <= Pshift;

                count <= count - 1;

                if (count == 1) begin
                    busy   <= 0;
                    done   <= 1;
                    result <= Pshift[63:0];
                end
            end
        end
    end
endmodule