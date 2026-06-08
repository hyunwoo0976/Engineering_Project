`default_nettype none
module FMUL_core #(parameter W=32)(
    input wire s1_en,
    input wire s1_SIGN_A,s1_SIGN_B,
    input wire [7:0]s1_EXPO_A,s1_EXPO_B,
    input wire [22:0]s1_FRAC_A,s1_FRAC_B,
    input wire clk,reset,
    input wire [2:0]s4_rm,
    output wire [W-1:0]s6_MUL_out,
    output wire s6_OF,s6_UF
);
    // ====== [Stage 1] ========================================================================
   

    // ====== [Stage 2] ========================================================================
    wire s2_SIGN_A,s2_SIGN_B;
    wire s2_SIGN;

    wire [7:0]s2_EXPO_A, s2_EXPO_B;
    wire [8:0]s2_EXPO_ADD;

    wire [22:0]s2_FRAC_A, s2_FRAC_B;
    wire [47:0]s2_FRAC_mul;
    wire s2_en;

    // ====== [Stage 3] ========================================================================
    wire s3_SIGN;

    wire [8:0]s3_EXPO_ADD;

    wire [47:0]s3_FRAC_mul;
    wire [22:0]s3_FRAC;
    wire s3_en;

    // ====== [Stage 4] ========================================================================
    wire s4_SIGN;

    wire [8:0] s4_EXPO_ADD;
    wire [7:0] s4_EXPO;
    wire [22:0] s4_FRAC;
    wire [47:0] s4_FRAC_mul;
    
    wire s4_count;
    wire s4_round_carry;
    wire s4_OF,s4_UF;
    wire s4_en;
    
    // ====== [Stage 5] ========================================================================
    wire s5_SIGN;

    wire [7:0]s5_EXPO;

    wire [22:0]s5_FRAC;
    wire s5_OF,s5_UF;
    wire s5_count, s5_round_carry;
    wire s5_en;

    // ====== [Stage 6] ========================================================================
    wire s6_SIGN;
    wire [7:0] s6_EXPO;
    wire [22:0]s6_FRAC;

    //==============================================================
    Pipe_reg_1clk #(.W(1)) reg_en_s1_s2(.clk(clk), .reset(reset), .D(s1_en), .Q(s2_en));
    Pipe_reg_1clk #(.W(1)) reg_en_s2_s3(.clk(clk), .reset(reset), .D(s2_en), .Q(s3_en));
    Pipe_reg_1clk #(.W(1)) reg_en_s3_s4(.clk(clk), .reset(reset), .D(s3_en), .Q(s4_en));
    Pipe_reg_1clk #(.W(1)) reg_en_s4_s5(.clk(clk), .reset(reset), .D(s4_en), .Q(s5_en));
    
    //==============================================================

    Pipe_reg_1clk_en #(.W(1)) reg_SIGN_A_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_SIGN_A), .Q(s2_SIGN_A));
    Pipe_reg_1clk_en #(.W(1)) reg_SIGN_B_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_SIGN_B), .Q(s2_SIGN_B));

    MUL_SIGN sign_cal(
        .SIGN_A(s2_SIGN_A),
        .SIGN_B(s2_SIGN_B),
        .SIGN(s2_SIGN)
    );

    Pipe_reg_1clk_en #(.W(1)) reg_SIGN_s2_s3(.clk(clk), .reset(reset), .en(s2_en), .D(s2_SIGN), .Q(s3_SIGN));
    Pipe_reg_1clk_en #(.W(1)) reg_SIGN_s3_s4(.clk(clk), .reset(reset), .en(s3_en), .D(s3_SIGN), .Q(s4_SIGN));
    Pipe_reg_1clk_en #(.W(1)) reg_SIGN_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_SIGN), .Q(s5_SIGN));
    Pipe_reg_1clk_en #(.W(1)) reg_SIGN_s5_s6(.clk(clk), .reset(reset), .en(s5_en), .D(s5_SIGN), .Q(s6_SIGN));
   
    //==============================================================
    Pipe_reg_1clk_en #(.W(8)) reg_EXPO_A_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_EXPO_A), .Q(s2_EXPO_A));
    Pipe_reg_1clk_en #(.W(8)) reg_EXPO_B_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_EXPO_B), .Q(s2_EXPO_B));
    
    MUL_EXPO_ADD expo_add(
        .EXPO_A(s2_EXPO_A),
        .EXPO_B(s2_EXPO_B),
        .EXPO_ADD(s2_EXPO_ADD)
    );

    Pipe_reg_1clk_en #(.W(9)) reg_EXPO_ADD_s2_s3(.clk(clk), .reset(reset), .en(s2_en), .D(s2_EXPO_ADD), .Q(s3_EXPO_ADD));
    Pipe_reg_1clk_en #(.W(9)) reg_EXPO_ADD_s3_s4(.clk(clk), .reset(reset), .en(s3_en), .D(s3_EXPO_ADD), .Q(s4_EXPO_ADD));

    MUL_EXPO mul_expo(
        .EXPO_ADD(s4_EXPO_ADD),
        .count(s4_count),
        .round_carry(s4_round_carry),
        .EXPO(s4_EXPO),
        .OF(s4_OF),
        .UF(s4_UF)
    );

    Pipe_reg_1clk_en #(.W(8)) reg4_EXPO_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_EXPO), .Q(s5_EXPO));
    Pipe_reg_1clk_en #(.W(8)) reg5_EXPO_s5_s6(.clk(clk), .reset(reset), .en(s5_en), .D(s5_EXPO), .Q(s6_EXPO));
    
    Pipe_reg_1clk_en #(.W(1)) reg4_OF_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_OF), .Q(s5_OF));
    Pipe_reg_1clk_en #(.W(1)) reg4_UF_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_UF), .Q(s5_UF));

    Pipe_reg_1clk_en #(.W(1)) reg5_OF_s5_s6(.clk(clk), .reset(reset), .en(s5_en), .D(s5_OF), .Q(s6_OF));
    Pipe_reg_1clk_en #(.W(1)) reg5_UF_s5_s6(.clk(clk), .reset(reset), .en(s5_en), .D(s5_UF), .Q(s6_UF));

    //==============================================================
    Pipe_reg_1clk_en #(.W(23)) reg_FRAC_A_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_FRAC_A), .Q(s2_FRAC_A));
    Pipe_reg_1clk_en #(.W(23)) reg_FRAC_B_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_FRAC_B), .Q(s2_FRAC_B));

    Multiplier #(.W(48)) frac_mul(
        .FRAC_A({1'b1,s2_FRAC_A}),
        .FRAC_B({1'b1,s2_FRAC_B}),
        .FRAC_mul(s2_FRAC_mul)
    );

    Pipe_reg_1clk_en #(.W(48)) reg2_FRAC_mul_s2_s3 (.clk(clk), .reset(reset), .en(s2_en), .D(s2_FRAC_mul), .Q(s3_FRAC_mul));
    Pipe_reg_1clk_en #(.W(48)) reg3_FRAC_mul_s3_s4 (.clk(clk), .reset(reset), .en(s3_en), .D(s3_FRAC_mul), .Q(s4_FRAC_mul));

    Normalization_MUL #(.W(48)) s4_frac_nor(
        .FRAC_mul(s4_FRAC_mul),
        .FRAC_out(s4_FRAC),
        .rm(s4_rm),
        .count(s4_count),
        .round_carry(s4_round_carry)
    );

    Pipe_reg_1clk_en #(.W(1)) reg4_count_s3_s4(.clk(clk), .reset(reset), .en(s4_en), .D(s4_count), .Q(s5_count));
    Pipe_reg_1clk_en #(.W(1)) reg4_round_carry_s3_s4(.clk(clk), .reset(reset), .en(s4_en), .D(s4_round_carry), .Q(s5_round_carry));
    
    Pipe_reg_1clk_en #(.W(23)) reg4_FRAC_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_FRAC), .Q(s5_FRAC));
    Pipe_reg_1clk_en #(.W(23)) reg5_FRAC_s5_s6(.clk(clk), .reset(reset), .en(s5_en), .D(s5_FRAC), .Q(s6_FRAC));

    //==============================================================
    Exception_Handler #(.W(32)) s6_final(
        .SIGN(s6_SIGN),
        .EXPO(s6_EXPO),
        .FRAC(s6_FRAC),
        .result_out(s6_MUL_out)
    );
endmodule
`default_nettype wire