`default_nettype none
module FADD_core #(parameter W=32)(
    input wire s1_en,
    input wire s1_SIGN_A,s1_SIGN_B,
    input wire [7:0]s1_EXPO_A,s1_EXPO_B,
    input wire [22:0]s1_FRAC_A,s1_FRAC_B,
    input wire clk,reset,
    input wire [2:0] s6_rm,
    input [1:0]op,
    output wire s6_error,s6_OF,s6_UF,
    output wire [W-1:0]s6_ADD_out
);

    // ====== [Stage 1] ========================================================================
    wire s1_mode, s1_EXPO_direction, s1_EXPO_doing_A, s1_EXPO_doing_B, s1_bigger;
    wire [7:0]s1_EXPO_count;
    wire [7:0]s1_EXPO_big;
    wire s1_op;
    // ====== [Stage 2] ========================================================================
    wire [47:0]s2_FRAC_A, s2_FRAC_B, s2_FRAC_shifted_A, s2_FRAC_shifted_B, s2_FRAC_cond_A, s2_FRAC_cond_B;

    wire [7:0]s2_EXPO_big, s2_EXPO_count;

    wire s2_SIGN_A, s2_SIGN_B;
    wire s2_EXPO_direction, s2_EXPO_doing_A, s2_EXPO_doing_B, s2_mode, s2_eff_sub, s2_bigger, s2_final_SIGN;
    wire s2_op;
    wire s2_en;
    // ====== [Stage 3] ========================================================================
    wire [47:0]s3_FRAC_A, s3_FRAC_B, s3_FRAC_shifted_A, s3_FRAC_shifted_B, s3_FRAC_Sum1, s3_FRAC_Sum2, s3_FRAC_SUM;

    wire [7:0]s3_EXPO_big;

    wire s3_eff_sub, s3_FRAC_Cout1, s3_final_SIGN;
    wire s3_op;
    wire s3_en;
    // ====== [Stage 4] ========================================================================
    wire [48:0]s4_FRAC_nor_FRAC;
    wire [47:0]s4_FRAC_Sum;

    wire [7:0]s4_EXPO_big, s4_FRAC_nor_count;

    wire s4_FRAC_Cout, s4_FRAC_nor_direction, s4_FRAC_nor_doing, s4_final_SIGN;
    wire s4_op;
    wire s4_en;
    // ====== [Stage 5] ========================================================================
    wire [48:0]s5_FRAC_nor_FRAC, s5_FRAC_shifted;
    wire [8:0]s5_EXPO;
    wire [7:0]s5_FRAC_nor_count;
    wire [7:0]s5_EXPO_big;

    wire s5_FRAC_nor_direction, s5_FRAC_nor_doing, s5_final_SIGN;
    wire s5_op;
    wire s5_en;
    // ====== [Stage 6] ========================================================================
    wire [47:0]s6_FRAC_shifted;

    wire [31:0]s6_result_out;

    wire [22:0]s6_final_FRAC;

    wire [8:0]s6_EXPO, s6_final_EXPO;

    wire s6_Rounding_count, s6_final_SIGN;

    wire s6_op;

//===================================================================================================================================
//===================================================================================================================================
    //========================================[FRAC]=====================================================
    Pipe_reg_1clk #(.W(1))reg0_en_s1_s2(.clk(clk), .reset(reset), .D(s1_en), .Q(s2_en));
    Pipe_reg_1clk #(.W(1))reg0_en_s2_s3(.clk(clk), .reset(reset), .D(s2_en), .Q(s3_en));
    Pipe_reg_1clk #(.W(1))reg0_en_s3_s4(.clk(clk), .reset(reset), .D(s3_en), .Q(s4_en));
    Pipe_reg_1clk #(.W(1))reg0_en_s4_s5(.clk(clk), .reset(reset), .D(s4_en), .Q(s5_en));
    // ======================================[stage 2]====================================================

    Pipe_reg_1clk_en #(.W(48)) reg1_FRAC_A_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D({1'b1,s1_FRAC_A,24'b0}), .Q(s2_FRAC_A));
    Pipe_reg_1clk_en #(.W(48)) reg1_FRAC_B_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D({1'b1,s1_FRAC_B,24'b0}), .Q(s2_FRAC_B));

    barrel_shifter #(.W(48))FRAC_shifter1_A_s2(
        .direction(s2_EXPO_direction),
        .count(s2_EXPO_count),
        .doing(s2_EXPO_doing_A),
        .shift(s2_FRAC_A),
        .SHIFT(s2_FRAC_shifted_A)
    );
    barrel_shifter #(.W(48))FRAC_shifter1_B_s2(
        .direction(s2_EXPO_direction),
        .count(s2_EXPO_count),
        .doing(s2_EXPO_doing_B),
        .shift(s2_FRAC_B),
        .SHIFT(s2_FRAC_shifted_B)
    );

    Pipe_reg_1clk_en #(.W(1)) reg1_SIGN_A_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_SIGN_A), .Q(s2_SIGN_A));
    Pipe_reg_1clk_en #(.W(1)) reg1_SIGN_B_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_SIGN_B), .Q(s2_SIGN_B));
    
    Pipe_reg_1clk #(.W(1))reg0_op_s0_s1(.clk(clk), .reset(reset), .D(op[0]), .Q(s1_op));
    Pipe_reg_1clk_en #(.W(1))reg1_op_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_op), .Q(s2_op));

    Mode_Detector mode_dec_s2(
        .sign_A(s2_SIGN_A),
        .sign_B(s2_SIGN_B),
        .mode(s2_op),
        .eff_sub(s2_eff_sub)
    );
    Cond_Inverter #(.W(48))co_inAB_s2(
        .eff_sub(s2_eff_sub),
        .FRAC_B(s2_FRAC_shifted_B),
        .FRAC_cla_B(s2_FRAC_cond_B)
    );
    Cond_Inverter #(.W(48))co_inBA_s2(
        .eff_sub(s2_eff_sub),
        .FRAC_B(s2_FRAC_shifted_A),
        .FRAC_cla_B(s2_FRAC_cond_A)
    );
// ======================================[stage 3]====================================================

    Pipe_reg_1clk_en #(.W(1))reg2_FRAC_eff_sub_s2_s3(.clk(clk), .reset(reset), .en(s2_en), .D(s2_eff_sub), .Q(s3_eff_sub));
    Pipe_reg_1clk_en #(.W(48))reg2_FRAC_shifted_A_s2_s3(.clk(clk), .reset(reset), .en(s2_en), .D(s2_FRAC_shifted_A), .Q(s3_FRAC_A));
    Pipe_reg_1clk_en #(.W(48))reg2_FRAC_shifted_B_s2_s3(.clk(clk), .reset(reset), .en(s2_en), .D(s2_FRAC_shifted_B), .Q(s3_FRAC_B));
    Pipe_reg_1clk_en #(.W(48))reg2_FRAC_A_s2_s3(.clk(clk), .reset(reset), .en(s2_en), .D(s2_FRAC_cond_A), .Q(s3_FRAC_shifted_A));
    Pipe_reg_1clk_en #(.W(48))reg2_FRAC_B_s2_s3(.clk(clk), .reset(reset), .en(s2_en), .D(s2_FRAC_cond_B), .Q(s3_FRAC_shifted_B));


    CLA #(.W(48))cla_AB_s3(
        .A(s3_FRAC_A),
        .B(s3_FRAC_shifted_B),
        .Cin(s3_eff_sub),
        .Sum(s3_FRAC_Sum1),
        .Cout(s3_FRAC_Cout1)
    );
    CLA #(.W(48))cla_BA_s3(
        .A(s3_FRAC_B),
        .B(s3_FRAC_shifted_A),
        .Cin(s3_eff_sub),
        .Sum(s3_FRAC_Sum2),
        .Cout()
    );
    Magnitude_Restoration #(.W(48))magn_restore_s3(
        .Sum_1(s3_FRAC_Sum1),
        .cout_1(s3_FRAC_Cout1),
        .Sum_2(s3_FRAC_Sum2),
        .eff_sub(s3_eff_sub),
        .SUM(s3_FRAC_SUM)
    );
// ======================================[stage 4]====================================================

    Pipe_reg_1clk_en #(.W(48))reg3_FRAC_Sum_s3_s4(.clk(clk), .reset(reset), .en(s3_en), .D(s3_FRAC_SUM), .Q(s4_FRAC_Sum));
    Pipe_reg_1clk_en #(.W(1))reg3_FRAC_Cout_s3_s4(.clk(clk), .reset(reset), .en(s3_en), .D(s3_FRAC_Cout1), .Q(s4_FRAC_Cout));

    Normalization_Controller#(.W(48)) normalization_s4(
        .Sum(s4_FRAC_Sum),
        .Cout(s4_FRAC_Cout),
        .nor_FRAC(s4_FRAC_nor_FRAC),
        .count(s4_FRAC_nor_count),
        .direction(s4_FRAC_nor_direction),
        .doing(s4_FRAC_nor_doing)
    );
// ======================================[stage 5]====================================================

    Pipe_reg_1clk_en #(.W(8))reg4_FRAC_count_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_FRAC_nor_count), .Q(s5_FRAC_nor_count));
    Pipe_reg_1clk_en #(.W(1))reg4_FRAC_direction_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_FRAC_nor_direction), .Q(s5_FRAC_nor_direction));
    Pipe_reg_1clk_en #(.W(1))reg4_FRAC_doing_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_FRAC_nor_doing), .Q(s5_FRAC_nor_doing));
    Pipe_reg_1clk_en #(.W(49))reg4_FRAC_nor_FRAC_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_FRAC_nor_FRAC), .Q(s5_FRAC_nor_FRAC));

    barrel_shifter #(.W(49))FRAC_shifter2_s5(
        .direction(s5_FRAC_nor_direction),
        .count(s5_FRAC_nor_count),
        .doing(s5_FRAC_nor_doing),
        .shift(s5_FRAC_nor_FRAC),
        .SHIFT(s5_FRAC_shifted)
    );

    // ======================================[stage 6]====================================================
    Pipe_reg_1clk_en #(.W(48))reg5_FRAC_shifted_s5_s6(.clk(clk), .reset(reset), .en(s5_en), .D(s5_FRAC_shifted[47:0]), .Q(s6_FRAC_shifted));

    Rounding #(.W(48))fin_frac_s6(
        .FRAC(s6_FRAC_shifted),
        .rm(s6_rm),
        .final_FRAC(s6_final_FRAC),
        .count(s6_Rounding_count),
        .error(s6_error)
    );

//===================================================================================================================================
//===================================================================================================================================
    //========================================[EXPO]=====================================================

// ======================================[stage 1]====================================================
    EXPO_SUB #(.W(8))EXPO_sub_s1(
        .EXPO_a(s1_EXPO_A),
        .EXPO_b(s1_EXPO_B),
        .count(s1_EXPO_count),
        .direction(s1_EXPO_direction),
        .doing_A(s1_EXPO_doing_A),
        .doing_B(s1_EXPO_doing_B),
        .EXPO_big(s1_EXPO_big)
    );

// ======================================[stage 2]====================================================
    Pipe_reg_1clk_en #(.W(8))reg1_EXPO_count_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_EXPO_count), .Q(s2_EXPO_count));
    Pipe_reg_1clk_en #(.W(1))reg1_EXPO_direction_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_EXPO_direction), .Q(s2_EXPO_direction));
    Pipe_reg_1clk_en #(.W(1))reg1_EXPO_doing_A_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_EXPO_doing_A), .Q(s2_EXPO_doing_A));
    Pipe_reg_1clk_en #(.W(1))reg1_EXPO_doing_B_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_EXPO_doing_B), .Q(s2_EXPO_doing_B));
    Pipe_reg_1clk_en #(.W(8))reg1_EXPO_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_EXPO_big), .Q(s2_EXPO_big));

// ======================================[stage 3]====================================================
    Pipe_reg_1clk_en #(.W(8))reg2_EXPO_s2_s3(.clk(clk), .reset(reset), .en(s2_en), .D(s2_EXPO_big), .Q(s3_EXPO_big));

// ======================================[stage 4]====================================================
    Pipe_reg_1clk_en #(.W(8))reg3_EXPO_s3_s4(.clk(clk), .reset(reset), .en(s3_en), .D(s3_EXPO_big), .Q(s4_EXPO_big));

// ======================================[stage 5]====================================================
    Pipe_reg_1clk_en #(.W(8))reg4_EXPO_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_EXPO_big), .Q(s5_EXPO_big));
    
    EXPO_CAL #(.W(9))expo_cal_s5(
        .EXPO_in({1'b0,s5_EXPO_big}),
        .count(s5_FRAC_nor_count[5:0]),
        .direction(s5_FRAC_nor_direction),
        .doing(s5_FRAC_nor_doing),
        .EXPO_out(s5_EXPO)
    );
// ======================================[stage 6]====================================================
    Pipe_reg_1clk_en #(.W(9))reg5_EXPO_s5_s6(.clk(clk), .reset(reset), .en(s5_en), .D(s5_EXPO), .Q(s6_EXPO));

    EXPO_MUX #(.W(9)) expo_mux_s6(
        .EXPO_in(s6_EXPO),
        .count(s6_Rounding_count),
        .EXPO_out(s6_final_EXPO)
    );

//===================================================================================================================================
//===================================================================================================================================
    //========================================[SIGN]=====================================================
// ======================================[stage 1]====================================================
    comparator s1_mag(
        .EXPO_A(s1_EXPO_A),
        .EXPO_B(s1_EXPO_B),
        .FRAC_A(s1_FRAC_A),
        .FRAC_B(s1_FRAC_B),
        .bigger(s1_bigger)
    );

// ======================================[stage 2]====================================================
    Pipe_reg_1clk_en #(.W(1))reg1_SIGN_bigger_s1_s2(.clk(clk), .reset(reset), .en(s1_en), .D(s1_bigger), .Q(s2_bigger));

    SIGN fin_sign_s2(
        .SIGN_A(s2_SIGN_A),
        .SIGN_B(s2_SIGN_B),
        .mode(s2_op),
        .bigger(s2_bigger),
        .result_SIGN(s2_final_SIGN)
    );

// ======================================[stage 3]====================================================
    Pipe_reg_1clk_en #(.W(1))reg2_SIGN_s2_s3(.clk(clk), .reset(reset), .en(s2_en), .D(s2_final_SIGN), .Q(s3_final_SIGN));

// ======================================[stage 4]====================================================
    Pipe_reg_1clk_en #(.W(1))reg3_SIGN_s3_s4(.clk(clk), .reset(reset), .en(s3_en), .D(s3_final_SIGN), .Q(s4_final_SIGN));

// ======================================[stage 5]====================================================
    Pipe_reg_1clk_en #(.W(1))reg4_SIGN_s4_s5(.clk(clk), .reset(reset), .en(s4_en), .D(s4_final_SIGN), .Q(s5_final_SIGN));

// ======================================[stage 6]====================================================
    Pipe_reg_1clk_en #(.W(1))reg5_SIGN_s5_s6(.clk(clk), .reset(reset), .en(s5_en), .D(s5_final_SIGN), .Q(s6_final_SIGN));
   
    //=============================================================================================


//===================================================================================================================================
//===================================================================================================================================
// ======================================[stage 6]====================================================
    Exception_Handler_ADD s6_final(
        .SIGN(s6_final_SIGN),
        .EXPO(s6_final_EXPO),
        .FRAC(s6_final_FRAC),
        .overflow_flag(s6_OF),
        .underflow_flag(s6_UF),
        .final_result(s6_ADD_out)
    );

endmodule
`default_nettype wire