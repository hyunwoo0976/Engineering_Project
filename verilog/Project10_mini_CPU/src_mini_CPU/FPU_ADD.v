`default_nettype none
module FPU_ADD #(parameter W=32)(
    input [W-1:0]IN_a,IN_b,
    input mode,clk,reset,
    output error,OF,UF,
    output [W-1:0]result_out
);

    // ====== [Stage 1] ========================================================================
    wire [31:0]s1_IN_A, s1_IN_B;

    wire s1_mode;

    wire s1_SIGN_A, s1_SIGN_B;
    wire [7:0]s1_EXPO_A, s1_EXPO_B;
    wire [22:0]s1_FRAC_A, s1_FRAC_B;

    // ====== [Stage 2] ========================================================================
    wire [22:0] s2_FRAC_A, s2_FRAC_B;
    wire s2_SIGN_A, s2_SIGN_B;
    wire [7:0] s2_EXPO_A, s2_EXPO_B;
    wire s2_mode;
    wire s2_bigger;
    wire [7:0] s2_EXPO_count;
    wire s2_EXPO_direction;
    wire s2_EXPO_doing_A, s2_EXPO_doing_B;
    wire [7:0] s2_EXPO_big;
    // ====== [Stage 3] ========================================================================
    wire s3_SIGN_A, s3_SIGN_B;
    wire [47:0]s3_FRAC_A, s3_FRAC_B;
    wire s3_bigger;
    wire s3_final_SIGN;
    wire [7:0]s3_EXPO_big;

    wire s3_mode;

    wire s3_EXPO_direction;
    wire [7:0] s3_EXPO_count;
    wire s3_EXPO_doing_A, s3_EXPO_doing_B;
    wire [47:0] s3_FRAC_shifted_A, s3_FRAC_shifted_B;

    // ====== [Stage 4] ========================================================================
    wire [47:0]s4_FRAC_shifted_A, s4_FRAC_shifted_B;
    wire s4_SIGN_A, s4_SIGN_B;
    wire s4_final_SIGN;
    wire s4_mode;
    wire [7:0]s4_EXPO_big;

    wire s4_eff_sub;
    wire s4_Cin;
    wire [47:0] s4_FRAC_B;

    // ====== [Stage 5] ========================================================================
    wire s5_Cin;
    wire [47:0] s5_FRAC_A;
    wire [47:0] s5_FRAC_B;
    wire s5_eff_sub;
    wire s5_final_SIGN;
    wire [7:0]s5_EXPO_big;

    wire s5_FRAC_Cout;
    wire [47:0]s5_FRAC_Sum;

    // ====== [Stage 6] ========================================================================
    wire [47:0] s6_FRAC_Sum;
    wire s6_FRAC_Cout;
    wire s6_eff_sub;
    wire s6_final_SIGN;
    wire [7:0]s6_EXPO_big;

    wire [47:0] s6_FRAC_SUM;

    // ====== [Stage 7] ========================================================================
    wire [47:0] s7_FRAC_Sum;
    wire s7_FRAC_Cout;
    wire s7_final_SIGN;
    wire [7:0]s7_EXPO_big;

    wire [48:0] s7_FRAC_nor_FRAC;
    wire [7:0] s7_FRAC_nor_count;
    wire s7_FRAC_nor_direction;
    wire s7_FRAC_nor_doing;

    // ====== [Stage 8] ========================================================================
    wire [7:0] s8_FRAC_nor_count;
    wire s8_FRAC_nor_direction;
    wire s8_FRAC_nor_doing;
    wire [48:0] s8_FRAC_nor_FRAC;
    wire [7:0]s8_EXPO_big;

    wire [48:0] s8_FRAC_shifted;
    wire s8_final_SIGN;
    wire [8:0] s8_EXPO;

    // ====== [Stage 9] ========================================================================
    wire [47:0] s9_FRAC_shifted;
    wire [22:0] s9_final_FRAC;
    wire s9_Rounding_count;
    wire s9_final_SIGN;
    wire [8:0] s9_EXPO;
    wire s9_Rounding_direction;
    wire s9_Rounding_doing;

    // ====== [Stage 10] ========================================================================
    wire [22:0]s10_final_FRAC;
    wire s10_final_SIGN;
    wire [8:0] s10_EXPO;
    wire s10_Rounding_count;
    wire s10_Rounding_direction;
    wire s10_Rounding_doing;
    wire [8:0] s10_final_EXPO;

    // ====== [Stage 11] ========================================================================
    wire s11_final_SIGN;
    wire [8:0] s11_final_EXPO;
    wire [22:0] s11_final_FRAC;


    Pipe_reg_1clk #(.W(32))reg0_A_s0_s1(.clk(clk), .reset(reset), .D(IN_a), .Q(s1_IN_A));
    Pipe_reg_1clk #(.W(32))reg0_B_s0_s1(.clk(clk), .reset(reset),.D(IN_b), .Q(s1_IN_B));

    FPU_unpack #(.W(32))unpack_A_s1(
        .IN(s1_IN_A),
        .SIGN(s1_SIGN_A),
        .EXPO(s1_EXPO_A),
        .FRAC(s1_FRAC_A)
    );

    FPU_unpack #(.W(32))unpack_B_s1(
        .IN(s1_IN_B),
        .SIGN(s1_SIGN_B),
        .EXPO(s1_EXPO_B),
        .FRAC(s1_FRAC_B)
    );

    Pipe_reg_1clk #(.W(23)) reg1_FRAC_A_s1_s2(.clk(clk), .reset(reset), .D(s1_FRAC_A), .Q(s2_FRAC_A));
    Pipe_reg_1clk #(.W(48)) reg1_FRAC_A_s2_s3(.clk(clk), .reset(reset), .D({1'b1,s2_FRAC_A,24'b0}), .Q(s3_FRAC_A));
    Pipe_reg_1clk #(.W(23)) reg1_FRAC_B_s1_s2(.clk(clk), .reset(reset), .D(s1_FRAC_B), .Q(s2_FRAC_B));
    Pipe_reg_1clk #(.W(48)) reg1_FRAC_B_s2_s3(.clk(clk), .reset(reset), .D({1'b1,s2_FRAC_B,24'b0}), .Q(s3_FRAC_B));

    barrel_shifter #(.W(48))FRAC_shifter1_A_s3(
        .direction(s3_EXPO_direction),
        .count(s3_EXPO_count),
        .doing(s3_EXPO_doing_A),
        .shift(s3_FRAC_A),
        .SHIFT(s3_FRAC_shifted_A)
    );
    barrel_shifter #(.W(48))FRAC_shifter1_B_s3(
        .direction(s3_EXPO_direction),
        .count(s3_EXPO_count),
        .doing(s3_EXPO_doing_B),
        .shift(s3_FRAC_B),
        .SHIFT(s3_FRAC_shifted_B)
    );

    Pipe_reg_1clk #(.W(48)) reg2_FRAC_A_s3_s4(.clk(clk), .reset(reset), .D(s3_FRAC_shifted_A), .Q(s4_FRAC_shifted_A));
    Pipe_reg_1clk #(.W(48)) reg2_FRAC_B_s3_s4(.clk(clk), .reset(reset), .D(s3_FRAC_shifted_B), .Q(s4_FRAC_shifted_B));

    Pipe_reg_1clk #(.W(1)) reg1_SIGN_A_s1_s2(.clk(clk), .reset(reset), .D(s1_SIGN_A), .Q(s2_SIGN_A));
    Pipe_reg_1clk #(.W(1)) reg1_SIGN_A_s2_s3(.clk(clk), .reset(reset), .D(s2_SIGN_A), .Q(s3_SIGN_A));
    Pipe_reg_1clk #(.W(1)) reg2_SIGN_A_s3_s4(.clk(clk), .reset(reset), .D(s3_SIGN_A), .Q(s4_SIGN_A));

    Pipe_reg_1clk #(.W(1)) reg1_SIGN_B_s1_s2(.clk(clk), .reset(reset), .D(s1_SIGN_B), .Q(s2_SIGN_B));
    Pipe_reg_1clk #(.W(1)) reg1_SIGN_B_s2_s3(.clk(clk), .reset(reset), .D(s2_SIGN_B), .Q(s3_SIGN_B));
    Pipe_reg_1clk #(.W(1)) reg2_SIGN_B_s3_s4(.clk(clk), .reset(reset), .D(s3_SIGN_B), .Q(s4_SIGN_B));
    
    Pipe_reg_1clk #(.W(1))reg0_mode_s0_s1(.clk(clk), .reset(reset), .D(mode), .Q(s1_mode));
    Pipe_reg_1clk #(.W(1))reg1_mode_s1_s2(.clk(clk), .reset(reset), .D(s1_mode), .Q(s2_mode));
    Pipe_reg_1clk #(.W(1))reg2_mode_s2_s3(.clk(clk), .reset(reset), .D(s2_mode), .Q(s3_mode));
    Pipe_reg_1clk #(.W(1))reg3_mode_s3_s4(.clk(clk), .reset(reset), .D(s3_mode), .Q(s4_mode));

    Mode_Detector mode_dec_s4(
        .sign_A(s4_SIGN_A),
        .sign_B(s4_SIGN_B),
        .mode(s4_mode),
        .eff_sub(s4_eff_sub)
    );
    Cond_Inverter #(.W(48))co_in_s4(
        .eff_sub(s4_eff_sub),
        .FRAC_B(s4_FRAC_shifted_B),
        .FRAC_cla_B(s4_FRAC_B),
        .Cin(s4_Cin)
    );

    Pipe_reg_1clk #(.W(1))reg4_FRAC_Cin_s4_s5(.clk(clk), .reset(reset), .D(s4_Cin), .Q(s5_Cin));
    Pipe_reg_1clk #(.W(48))reg4_FRAC_A_s4_s5(.clk(clk), .reset(reset), .D(s4_FRAC_shifted_A), .Q(s5_FRAC_A));
    Pipe_reg_1clk #(.W(48))reg4_FRAC_B_s4_s5(.clk(clk), .reset(reset), .D(s4_FRAC_B), .Q(s5_FRAC_B));
    Pipe_reg_1clk #(.W(1))reg4_eff_sub_s4_s5(.clk(clk), .reset(reset), .D(s4_eff_sub), .Q(s5_eff_sub));

    CLA #(.W(48))cla_s5(
        .shift_FRAC_A(s5_FRAC_A),
        .shift_FRAC_B(s5_FRAC_B),
        .Cin(s5_Cin),
        .Sum(s5_FRAC_Sum),
        .Cout(s5_FRAC_Cout)
    );

    Pipe_reg_1clk #(.W(48))reg5_FRAC_Sum_s5_s6(.clk(clk), .reset(reset), .D(s5_FRAC_Sum), .Q(s6_FRAC_Sum));
    Pipe_reg_1clk #(.W(1))reg5_FRAC_Cout_s5_s6(.clk(clk), .reset(reset), .D(s5_FRAC_Cout), .Q(s6_FRAC_Cout));
    Pipe_reg_1clk #(.W(1))reg5_eff_sub_s5_s6(.clk(clk), .reset(reset), .D(s5_eff_sub), .Q(s6_eff_sub));

    Magnitude_Restoration #(.W(48))magn_restore_s6(
        .Sum(s6_FRAC_Sum),
        .Cout(s6_FRAC_Cout),
        .eff_sub(s6_eff_sub),
        .SUM(s6_FRAC_SUM)
    );

    Pipe_reg_1clk #(.W(48))reg6_FRAC_Sum_s6_s7(.clk(clk), .reset(reset), .D(s6_FRAC_SUM), .Q(s7_FRAC_Sum));
    Pipe_reg_1clk #(.W(1))reg6_FRAC_Cout_s6_s7(.clk(clk), .reset(reset), .D(s6_FRAC_Cout), .Q(s7_FRAC_Cout));

    Normalization_Controller#(.W(48)) normalization_s7(
        .Sum(s7_FRAC_Sum),
        .Cout(s7_FRAC_Cout),
        .nor_FRAC(s7_FRAC_nor_FRAC),
        .count(s7_FRAC_nor_count),
        .direction(s7_FRAC_nor_direction),
        .doing(s7_FRAC_nor_doing)
    );

    Pipe_reg_1clk #(.W(8))reg7_FRAC_count_s7_s8(.clk(clk), .reset(reset), .D(s7_FRAC_nor_count), .Q(s8_FRAC_nor_count));
    Pipe_reg_1clk #(.W(1))reg7_FRAC_direction_s7_s8(.clk(clk), .reset(reset), .D(s7_FRAC_nor_direction), .Q(s8_FRAC_nor_direction));
    Pipe_reg_1clk #(.W(1))reg7_FRAC_doing_s7_s8(.clk(clk), .reset(reset), .D(s7_FRAC_nor_doing), .Q(s8_FRAC_nor_doing));
    Pipe_reg_1clk #(.W(49))reg7_FRAC_nor_FRAC_s7_s8(.clk(clk), .reset(reset), .D(s7_FRAC_nor_FRAC), .Q(s8_FRAC_nor_FRAC));

    barrel_shifter #(.W(49))FRAC_shifter2_s8(
        .direction(s8_FRAC_nor_direction),
        .count(s8_FRAC_nor_count),
        .doing(s8_FRAC_nor_doing),
        .shift(s8_FRAC_nor_FRAC),
        .SHIFT(s8_FRAC_shifted)
    );

    Pipe_reg_1clk #(.W(48))reg8_FRAC_shifted_s7_s8(.clk(clk), .reset(reset), .D(s8_FRAC_shifted[47:0]), .Q(s9_FRAC_shifted));

    Rounding #(.W(48))fin_frac_s9(
        .FRAC(s9_FRAC_shifted),
        .final_FRAC(s9_final_FRAC),
        .count(s9_Rounding_count),
        .direction(s9_Rounding_direction),
        .doing(s9_Rounding_doing),
        .error(error)
    );
    
    Pipe_reg_1clk #(.W(1))reg_rounding_count_s9_s10(.clk(clk), .reset(reset), .D(s9_Rounding_count), .Q(s10_Rounding_count));
    Pipe_reg_1clk #(.W(1))reg_rounding_direction_s9_s10(.clk(clk), .reset(reset), .D(s9_Rounding_direction), .Q(s10_Rounding_direction));
    Pipe_reg_1clk #(.W(1))reg_rounding_doing_s9_s10(.clk(clk), .reset(reset), .D(s9_Rounding_doing), .Q(s10_Rounding_doing));
    Pipe_reg_1clk#(.W(23))reg_FRAC_final_s9_s10(.clk(clk), .reset(reset), .D(s9_final_FRAC), .Q(s10_final_FRAC));
    Pipe_reg_1clk#(.W(23))reg_FRAC_final_s10_s11(.clk(clk), .reset(reset), .D(s10_final_FRAC), .Q(s11_final_FRAC));

   //=============================================================================================

    Pipe_reg_1clk #(.W(8))reg1_EXPO_A(.clk(clk), .reset(reset), .D(s1_EXPO_A), .Q(s2_EXPO_A));
    Pipe_reg_1clk #(.W(8))reg1_EXPO_B(.clk(clk), .reset(reset), .D(s1_EXPO_B), .Q(s2_EXPO_B));

    EXPO_SUB #(.W(8))EXPO_sub_s2(
        .EXPO_a(s2_EXPO_A),
        .EXPO_b(s2_EXPO_B),
        .count(s2_EXPO_count),
        .direction(s2_EXPO_direction),
        .doing_A(s2_EXPO_doing_A),
        .doing_B(s2_EXPO_doing_B),
        .EXPO_big(s2_EXPO_big)
    );

    Pipe_reg_1clk #(.W(8))reg2_EXPO_count_s2_s3(.clk(clk), .reset(reset), .D(s2_EXPO_count), .Q(s3_EXPO_count));
    Pipe_reg_1clk #(.W(1))reg2_EXPO_direction_s2_s3(.clk(clk), .reset(reset), .D(s2_EXPO_direction), .Q(s3_EXPO_direction));
    Pipe_reg_1clk #(.W(1))reg2_EXPO_doing_A_s2_s3(.clk(clk), .reset(reset), .D(s2_EXPO_doing_A), .Q(s3_EXPO_doing_A));
    Pipe_reg_1clk #(.W(1))reg2_EXPO_doing_B_s2_s3(.clk(clk), .reset(reset), .D(s2_EXPO_doing_B), .Q(s3_EXPO_doing_B));
    Pipe_reg_1clk #(.W(8))reg2_EXPO_s2_s3(.clk(clk), .reset(reset), .D(s2_EXPO_big), .Q(s3_EXPO_big));

    Pipe_reg_1clk #(.W(8))reg3_EXPO_s3_s4(.clk(clk), .reset(reset), .D(s3_EXPO_big), .Q(s4_EXPO_big));
    Pipe_reg_1clk #(.W(8))reg4_EXPO_s4_s5(.clk(clk), .reset(reset), .D(s4_EXPO_big), .Q(s5_EXPO_big));
    Pipe_reg_1clk #(.W(8))reg5_EXPO_s5_s6(.clk(clk), .reset(reset), .D(s5_EXPO_big), .Q(s6_EXPO_big));
    Pipe_reg_1clk #(.W(8))reg6_EXPO_s6_s7(.clk(clk), .reset(reset), .D(s6_EXPO_big), .Q(s7_EXPO_big));
    Pipe_reg_1clk #(.W(8))reg7_EXPO_s7_s8(.clk(clk), .reset(reset), .D(s7_EXPO_big), .Q(s8_EXPO_big));
    
    EXPO_CAL #(.W(9))expo_cal_s8(
        .EXPO_in({1'b0,s8_EXPO_big}),
        .count(s8_FRAC_nor_count[5:0]),
        .direction(s8_FRAC_nor_direction),
        .doing(s8_FRAC_nor_doing),
        .EXPO_out(s8_EXPO)
    );

    Pipe_reg_1clk #(.W(9))reg8_EXPO_s8_s9(.clk(clk), .reset(reset), .D(s8_EXPO), .Q(s9_EXPO));
    Pipe_reg_1clk #(.W(9))reg8_EXPO_s9_s10(.clk(clk), .reset(reset), .D(s9_EXPO), .Q(s10_EXPO));

    EXPO_CAL #(.W(9))expo_cal_s10(
        .EXPO_in(s10_EXPO),
        .count({5'b0,s10_Rounding_count}),
        .direction(s10_Rounding_direction),
        .doing(s10_Rounding_doing),
        .EXPO_out(s10_final_EXPO)
    );

    Pipe_reg_1clk #(.W(9))reg8_EXPO_s10_s11(.clk(clk), .reset(reset), .D(s10_final_EXPO), .Q(s11_final_EXPO));

    //=============================================================================================

    comparator s2_mag(
        .EXPO_A(s2_EXPO_A),
        .EXPO_B(s2_EXPO_B),
        .FRAC_A(s2_FRAC_A),
        .FRAC_B(s2_FRAC_B),
        .bigger(s2_bigger)
    );

    Pipe_reg_1clk #(.W(1))reg2_SIGN_bigger_s2_s3(.clk(clk), .reset(reset), .D(s2_bigger), .Q(s3_bigger));

    SIGN fin_sign(
        .SIGN_A(s3_SIGN_A),
        .SIGN_B(s3_SIGN_B),
        .mode(s3_mode),
        .bigger(s3_bigger),
        .result_SIGN(s3_final_SIGN)
    );

    Pipe_reg_1clk #(.W(1))reg3_SIGN_s3_s4(.clk(clk), .reset(reset), .D(s3_final_SIGN), .Q(s4_final_SIGN));
    Pipe_reg_1clk #(.W(1))reg3_SIGN_s4_s5(.clk(clk), .reset(reset), .D(s4_final_SIGN), .Q(s5_final_SIGN));
    Pipe_reg_1clk #(.W(1))reg3_SIGN_s5_s6(.clk(clk), .reset(reset), .D(s5_final_SIGN), .Q(s6_final_SIGN));
    Pipe_reg_1clk #(.W(1))reg3_SIGN_s6_s7(.clk(clk), .reset(reset), .D(s6_final_SIGN), .Q(s7_final_SIGN));
    Pipe_reg_1clk #(.W(1))reg3_SIGN_s7_s8(.clk(clk), .reset(reset), .D(s7_final_SIGN), .Q(s8_final_SIGN));
    Pipe_reg_1clk #(.W(1))reg3_SIGN_s8_s9(.clk(clk), .reset(reset), .D(s8_final_SIGN), .Q(s9_final_SIGN));
    Pipe_reg_1clk #(.W(1))reg3_SIGN_s9_s10(.clk(clk), .reset(reset), .D(s9_final_SIGN), .Q(s10_final_SIGN));
    Pipe_reg_1clk #(.W(1))reg3_SIGN_s10_s11(.clk(clk), .reset(reset), .D(s10_final_SIGN), .Q(s11_final_SIGN));

    
    //=============================================================================================

    Exception_Handler_ADD s11_final(
        .SIGN(s11_final_SIGN),
        .EXPO(s11_final_EXPO),
        .FRAC(s11_final_FRAC),
        .overflow_flag(OF),
        .underflow_flag(UF),
        .final_result(result_out)
    );

endmodule
`default_nettype wire