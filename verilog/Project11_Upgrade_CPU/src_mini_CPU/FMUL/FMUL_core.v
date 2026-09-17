`default_nettype none
module FMUL_core #(
    parameter W = 32
) (
    input wire s1_en, s1_SIGN_A, s1_SIGN_B,
    input wire [7:0] s1_EXPO_A, s1_EXPO_B,
    input wire [22:0] s1_FRAC_A, s1_FRAC_B,
    input wire clk, reset,
    input wire [2:0] s4_rm,
    output wire [W-1:0] s6_MUL_out,
    output wire s6_OF, s6_UF, s6_NX
);
    wire s2_en, s3_en, s4_en, s5_en;
    Pipe_reg_1clk #(.W(1)) en2(
        .clk(clk),
        .reset(reset),
        .D(s1_en),
        .Q(s2_en)
    );
    Pipe_reg_1clk #(.W(1)) en3(
        .clk(clk),
        .reset(reset),
        .D(s2_en),
        .Q(s3_en)
    );
    Pipe_reg_1clk #(.W(1)) en4(
        .clk(clk),
        .reset(reset),
        .D(s3_en),
        .Q(s4_en)
    );
    Pipe_reg_1clk #(.W(1)) en5(
        .clk(clk),
        .reset(reset),
        .D(s4_en),
        .Q(s5_en)
    );

    // Stage 2: unpacked significands, effective exponents and product sign.
    wire [23:0] s2_FRAC_A, s2_FRAC_B;
    wire signed [11:0] s1_EXPO_base, s2_EXPO_base, s3_EXPO_base, s4_EXPO_base;
    wire [7:0] effective_A = (s1_EXPO_A == 0) ? 8'd1 : s1_EXPO_A;
    wire [7:0] effective_B = (s1_EXPO_B == 0) ? 8'd1 : s1_EXPO_B;
    assign s1_EXPO_base = $signed({4'b0, effective_A}) + $signed({4'b0, effective_B}) - 12'sd127;
    wire s2_SIGN, s3_SIGN, s4_SIGN;
    Pipe_reg_1clk_en #(.W(24)) frac_a(
        .clk(clk),
        .reset(reset),
        .en(s1_en),
        .D({(s1_EXPO_A != 0), s1_FRAC_A}),
        .Q(s2_FRAC_A)
    );
    Pipe_reg_1clk_en #(.W(24)) frac_b(
        .clk(clk),
        .reset(reset),
        .en(s1_en),
        .D({(s1_EXPO_B != 0), s1_FRAC_B}),
        .Q(s2_FRAC_B)
    );
    Pipe_reg_1clk_en #(.W(12)) exp2(
        .clk(clk),
        .reset(reset),
        .en(s1_en),
        .D(s1_EXPO_base),
        .Q(s2_EXPO_base)
    );
    Pipe_reg_1clk_en #(.W(1)) sign2(
        .clk(clk),
        .reset(reset),
        .en(s1_en),
        .D(s1_SIGN_A ^ s1_SIGN_B),
        .Q(s2_SIGN)
    );

    // Stage 3/4: retain every bit of the 48-bit product before rounding.
    wire [47:0] s2_FRAC_mul, s3_FRAC_mul, s4_FRAC_mul;
    Multiplier #(.W(48)) s2_u_multiplier(
        .FRAC_A(s2_FRAC_A),
        .FRAC_B(s2_FRAC_B),
        .FRAC_mul(s2_FRAC_mul)
    );
    Pipe_reg_1clk_en #(.W(48)) product3(
        .clk(clk),
        .reset(reset),
        .en(s2_en),
        .D(s2_FRAC_mul),
        .Q(s3_FRAC_mul)
    );
    Pipe_reg_1clk_en #(.W(48)) product4(
        .clk(clk),
        .reset(reset),
        .en(s3_en),
        .D(s3_FRAC_mul),
        .Q(s4_FRAC_mul)
    );
    Pipe_reg_1clk_en #(.W(12)) exp3(
        .clk(clk),
        .reset(reset),
        .en(s2_en),
        .D(s2_EXPO_base),
        .Q(s3_EXPO_base)
    );
    Pipe_reg_1clk_en #(.W(12)) exp4(
        .clk(clk),
        .reset(reset),
        .en(s3_en),
        .D(s3_EXPO_base),
        .Q(s4_EXPO_base)
    );
    Pipe_reg_1clk_en #(.W(1)) sign3(
        .clk(clk),
        .reset(reset),
        .en(s2_en),
        .D(s2_SIGN),
        .Q(s3_SIGN)
    );
    Pipe_reg_1clk_en #(.W(1)) sign4(
        .clk(clk),
        .reset(reset),
        .en(s3_en),
        .D(s3_SIGN),
        .Q(s4_SIGN)
    );

    wire [47:0] s4_FRAC_normalized;
    wire [8:0] s4_EXPO_normalized;
    wire [31:0] s4_result, s5_result;
    wire [2:0] s4_flags, s5_flags;
    Normalization_MUL s4_u_normalization_mul(
        .FRAC_mul(s4_FRAC_mul),
        .EXPO_base(s4_EXPO_base),
        .FRAC_out(s4_FRAC_normalized),
        .EXPO_out(s4_EXPO_normalized)
    );
    FP_rounding s4_u_rounding(
        .SIGN(s4_SIGN),
        .EXPO(s4_EXPO_normalized),
        .FRAC(s4_FRAC_normalized),
        .rm(s4_rm),
        .result(s4_result),
        .OF(s4_flags[2]),
        .UF(s4_flags[1]),
        .NX(s4_flags[0]),
        .final_FRAC(),
        .final_EXPO(),
        .count(),
        .inexact()
    );

    // Stage 5/6: result and flags travel together to the shared output mux.
    Pipe_reg_1clk_en #(.W(32)) result5(
        .clk(clk),
        .reset(reset),
        .en(s4_en),
        .D(s4_result),
        .Q(s5_result)
    );
    Pipe_reg_1clk_en #(.W(32)) result6(
        .clk(clk),
        .reset(reset),
        .en(s5_en),
        .D(s5_result),
        .Q(s6_MUL_out)
    );
    Pipe_reg_1clk_en #(.W(3)) flags5(
        .clk(clk),
        .reset(reset),
        .en(s4_en),
        .D(s4_flags),
        .Q(s5_flags)
    );
    Pipe_reg_1clk_en #(.W(3)) flags6(
        .clk(clk),
        .reset(reset),
        .en(s5_en),
        .D(s5_flags),
        .Q({s6_OF, s6_UF, s6_NX})
    );
endmodule
`default_nettype wire
