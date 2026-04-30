`default_nettype none
module FPU_MUL #(parameter W=32)(
    input [W-1:0]IN_A,IN_B,
    input clk,reset,
    output [W-1:0]result_out,
    output OF,UF
);
    // ====== [Stage 1] ========================================================================
    wire [31:0] s1_IN_A,s1_IN_B;
    wire s1_SIGN_A,s1_SIGN_B;
    wire [7:0]s1_EXPO_A,s1_EXPO_B;
    wire [22:0]s1_FRAC_A,s1_FRAC_B;

    // ====== [Stage 2] ========================================================================
    wire s2_SIGN_A,s2_SIGN_B;
    wire s2_SIGN;

    wire [7:0]s2_EXPO_A,s2_EXPO_B;
    wire [8:0]s2_EXPO_ADD;

    wire [22:0]s2_FRAC_A,s2_FRAC_B;
    wire [47:0]s2_FRAC_mul;

    // ====== [Stage 3] ========================================================================
    wire s3_SIGN;

    wire [8:0]s3_EXPO_ADD;

    wire [47:0]s3_FRAC_mul;
    wire [22:0]s3_FRAC;
    wire s3_count;
    wire s3_round_carry;

    // ====== [Stage 4] ========================================================================
    wire s4_SIGN;

    wire [8:0]s4_EXPO_ADD;
    wire [7:0]s4_EXPO;
    
    wire s4_count;
    wire s4_round_carry;
    wire [22:0]s4_FRAC;
    
    // ====== [Stage 5] ========================================================================
    wire s5_SIGN;

    wire [7:0]s5_EXPO;

    wire [22:0]s5_FRAC;

    Pipe_reg_1clk #(.W(32)) reg_IN_A_s0_s1(.clk(clk), .reset(reset), .D(IN_A), .Q(s1_IN_A));
    Pipe_reg_1clk #(.W(32)) reg_IN_B_s0_s1(.clk(clk), .reset(reset), .D(IN_B), .Q(s1_IN_B));

    FPU_unpack #(.W(32)) unpack_A_s1(
        .IN(s1_IN_A),
        .SIGN(s1_SIGN_A),
        .EXPO(s1_EXPO_A),
        .FRAC(s1_FRAC_A)
    );
    FPU_unpack #(.W(32)) unpack_B_s1(
        .IN(s1_IN_B),
        .SIGN(s1_SIGN_B),
        .EXPO(s1_EXPO_B),
        .FRAC(s1_FRAC_B)
    );

    //==============================================================
    Pipe_reg_1clk #(.W(1)) reg_SIGN_A_s1_s2(.clk(clk), .reset(reset), .D(s1_SIGN_A), .Q(s2_SIGN_A));
    Pipe_reg_1clk #(.W(1)) reg_SIGN_B_s1_s2(.clk(clk), .reset(reset), .D(s1_SIGN_B), .Q(s2_SIGN_B));

    MUL_SIGN sign_cal(
        .SIGN_A(s2_SIGN_A),
        .SIGN_B(s2_SIGN_B),
        .SIGN(s2_SIGN)
    );

    Pipe_reg_1clk #(.W(1)) reg_SIGN_s2_s3(.clk(clk), .reset(reset), .D(s2_SIGN), .Q(s3_SIGN));
    Pipe_reg_1clk #(.W(1)) reg_SIGN_s3_s4(.clk(clk), .reset(reset), .D(s3_SIGN), .Q(s4_SIGN));
    Pipe_reg_1clk #(.W(1)) reg_SIGN_s4_s5(.clk(clk), .reset(reset), .D(s4_SIGN), .Q(s5_SIGN));
   
    //==============================================================
    Pipe_reg_1clk #(.W(8)) reg_EXPO_A_s1_s2(.clk(clk), .reset(reset), .D(s1_EXPO_A), .Q(s2_EXPO_A));
    Pipe_reg_1clk #(.W(8)) reg_EXPO_B_s1_s2(.clk(clk), .reset(reset), .D(s1_EXPO_B), .Q(s2_EXPO_B));
    
    MUL_EXPO_ADD expo_add(
        .EXPO_A(s2_EXPO_A),
        .EXPO_B(s2_EXPO_B),
        .EXPO_ADD(s2_EXPO_ADD)
    );

    Pipe_reg_1clk #(.W(9)) reg_EXPO_ADD_s2_s3(.clk(clk), .reset(reset), .D(s2_EXPO_ADD), .Q(s3_EXPO_ADD));
    Pipe_reg_1clk #(.W(9)) reg_EXPO_ADD_s3_s4(.clk(clk), .reset(reset), .D(s3_EXPO_ADD), .Q(s4_EXPO_ADD));

    MUL_EXPO mul_expo(
        .EXPO_ADD(s4_EXPO_ADD),
        .count(s4_count),
        .round_carry(s4_round_carry),
        .EXPO(s4_EXPO),
        .OF(OF),
        .UF(UF)
    );

    Pipe_reg_1clk #(.W(8)) reg_EXPO_s4_s5(.clk(clk), .reset(reset), .D(s4_EXPO), .Q(s5_EXPO));

    //==============================================================
    Pipe_reg_1clk #(.W(23)) reg_FRAC_A_s1_s2(.clk(clk), .reset(reset), .D(s1_FRAC_A), .Q(s2_FRAC_A));
    Pipe_reg_1clk #(.W(23)) reg_FRAC_B_s1_s2(.clk(clk), .reset(reset), .D(s1_FRAC_B), .Q(s2_FRAC_B));

    Multiplier #(.W(48)) frac_mul(
        .FRAC_A({1'b1,s2_FRAC_A}),
        .FRAC_B({1'b1,s2_FRAC_B}),
        .FRAC_mul(s2_FRAC_mul)
    );

    Pipe_reg_1clk #(.W(48)) reg_FRAC_mul_s2_s3 (.clk(clk), .reset(reset), .D(s2_FRAC_mul), .Q(s3_FRAC_mul));

    Normalization_MUL #(.W(48)) frac_nor(
        .FRAC_mul(s3_FRAC_mul),
        .FRAC_out(s3_FRAC),
        .count(s3_count),
        .round_carry(s3_round_carry)
    );

    Pipe_reg_1clk #(.W(1)) reg_count_s3_s4(.clk(clk), .reset(reset), .D(s3_count), .Q(s4_count));
    Pipe_reg_1clk #(.W(1)) reg_round_carry_s3_s4(.clk(clk), .reset(reset), .D(s3_round_carry), .Q(s4_round_carry));
    Pipe_reg_1clk #(.W(23)) reg_FRAC_s3_s4(.clk(clk), .reset(reset), .D(s3_FRAC), .Q(s4_FRAC));
    Pipe_reg_1clk #(.W(23)) reg_FRAC_s4_s5(.clk(clk), .reset(reset), .D(s4_FRAC), .Q(s5_FRAC));

    //==============================================================
    Exception_Handler #(.W(32))final(
        .SIGN(s5_SIGN),
        .EXPO(s5_EXPO),
        .FRAC(s5_FRAC),
        .result_out(result_out)
    );
endmodule
`default_nettype wire