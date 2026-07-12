// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
// Note: Unmodified upstream file, used as-is in this integration


module divider_32c (
    input  logic         clk,
    input  logic         reset,    // active-high synchronous reset behavior in this module
    input  logic         enable,   // level-enable (toggle) — must be held high for duration
    input  logic         sign_sel, // Sign Selection
    input  logic [31:0]  numA,     // dividend
    input  logic [31:0]  denB,     // divisor
    output logic         done,     // one-cycle pulse when quotient/remainder valid
    output logic [31:0]  quotient,
    output logic [31:0]  remainder
);

    // Internal registers
    logic [31:0] dividend_reg;
    logic [31:0] divisor_reg;
    logic [32:0] rem;         // 33-bit remainder
    logic [31:0] q_reg;
    logic  [5:0] count;
    logic        busy;
    logic        div_by_zero; // flag

    logic [31:0] numA_reg, newA, newB;
    logic [31:0] u_quotient, u_remainder;
    logic        sign;

    always_comb begin

    case(sign_sel)
        // div,rem
        1'b0 : begin
                newA = numA[31] ? ~numA + 1'b1 : numA;
                newB = denB[31] ? ~denB + 1'b1 : denB;
                sign = numA[31] ^ denB[31];
                end
        // divu,remu
        1'b1 : begin
                newA = numA;
                newB = denB;
                sign = 1'b0;
                end
        // signed/signed by default
    default : begin
                newA = numA[31] ? ~numA + 1'b1 : numA;
                newB = denB[31] ? ~denB + 1'b1 : denB;
                sign = numA[31] ^ denB[31];
                end
    endcase

    quotient  = div_by_zero ? 32'hFFFFFFFF        :
                       sign ? ~u_quotient  + 1'b1 :
                               u_quotient;

    remainder = div_by_zero ? numA_reg            :
                       sign ? ~u_remainder + 1'b1 :
                               u_remainder;

    end

    // Combinational trial subtraction
    logic [32:0] trial;
    assign trial = { rem[31:0], dividend_reg[31] } - { 1'b0, divisor_reg };

    always @(posedge clk) begin
        if (reset) begin
            numA_reg     <= 32'b0;
            dividend_reg <= 32'b0;
            divisor_reg  <= 32'b0;
            rem          <= 33'b0;
            q_reg        <= 32'b0;
            u_quotient   <= 32'b0;
            u_remainder  <= 32'b0;
            count        <=  6'b0;
            busy         <=  1'b0;
            done         <=  1'b0;
            div_by_zero  <=  1'b0;
        end else begin
            // Start new division if enable and idle
            if (enable && !busy && !done) begin
                numA_reg     <= numA;
                dividend_reg <= newA;
                divisor_reg  <= newB;
                q_reg        <= 32'b0;
                rem          <= 33'b0;
                count        <= 6'd32;
                busy         <= 1'b1;
                done         <= 1'b0;
                // check divide-by-zero
                div_by_zero  <= (denB == 0);
            end else if (busy) begin
                if (div_by_zero) begin
                    busy      <= 0;
                    done      <= 1;
                    count     <= 6'd0;
                end else begin
                    // normal iterative division
                    if (!trial[32]) begin
                        if (count == 6'd1) begin
                            u_quotient  <= { q_reg[30:0], 1'b1 };
                            u_remainder <= trial[31:0];
                            rem         <= trial;
                            q_reg       <= { q_reg[30:0], 1'b1 };
                            dividend_reg <= { dividend_reg[30:0], 1'b0 };
                            busy        <= 0;
                            done        <= 1;
                            count       <= 6'd0;
                        end else begin
                            rem <= trial;
                            q_reg <= { q_reg[30:0], 1'b1 };
                            dividend_reg <= { dividend_reg[30:0], 1'b0 };
                            count <= count - 1;
                        end
                    end else begin
                        if (count == 6'd1) begin
                            u_quotient  <= { q_reg[30:0], 1'b0 };
                            u_remainder <= { rem[31:0], dividend_reg[31] };
                            rem         <= { rem[31:0], dividend_reg[31] };
                            q_reg       <= { q_reg[30:0], 1'b0 };
                            dividend_reg <= { dividend_reg[30:0], 1'b0 };
                            busy        <= 0;
                            done        <= 1;
                            count       <= 6'd0;
                        end else begin
                            rem <= { rem[31:0], dividend_reg[31] };
                            q_reg <= { q_reg[30:0], 1'b0 };
                            dividend_reg <= { dividend_reg[30:0], 1'b0 };
                            count <= count - 1;
                        end
                    end
                end
            end else begin
                done <= 1'b0; // idle
            end
        end
    end
endmodule