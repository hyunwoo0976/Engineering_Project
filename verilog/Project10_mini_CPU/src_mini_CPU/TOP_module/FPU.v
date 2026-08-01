module FPU #(parameter W=32)(
    input [W-1:0]IN_A,IN_B,
    input [1:0]op,
    input [2:0]rm,
    input FPU_en,
    input clk,reset,
    output [W-1:0]result_out,
    output error,OF,UF,
    output ZF,sign
);
    wire [31:0] s1_IN_A, s1_IN_B;
    
    wire s1_en;
    
    wire s1_SIGN_A, s1_SIGN_B;
    wire [7:0] s1_EXPO_A, s1_EXPO_B;
    wire [22:0] s1_FRAC_A, s1_FRAC_B;

    wire [31:0] s6_ADD_out, s6_MUL_out;
    wire [31:0] s6_final_out;

    wire [2:0] s1_rm, s2_rm, s3_rm, s4_rm, s5_rm, s6_rm;

    wire s6_OF_ADD, s6_OF_MUL, s6_UF_ADD, s6_UF_MUL, s6_error_ADD;
    wire s6_OF, s6_UF, s6_error;
    wire [1:0]s1_op;
    wire s2_op, s3_op, s4_op, s5_op, s6_op;
    wire s6_ZF, s6_sign;



    Pipe_reg_1clk #(.W(32)) reg0_IN_A(.clk(clk), .reset(reset), .D(IN_A), .Q(s1_IN_A));
    Pipe_reg_1clk #(.W(32)) reg0_IN_B(.clk(clk), .reset(reset), .D(IN_B), .Q(s1_IN_B));

    Pipe_reg_1clk #(.W(1)) reg0_FPU_en(.clk(clk), .reset(reset), .D(FPU_en), .Q(s1_en));


    FPU_unpack #(.W(32)) s1_u_unpack_A(
        .IN(s1_IN_A),
        .FPU_en(s1_en),
        .SIGN(s1_SIGN_A),
        .EXPO(s1_EXPO_A),
        .FRAC(s1_FRAC_A)
    );
    FPU_unpack #(.W(32)) s1_u_unpack_B(
        .IN(s1_IN_B),
        .FPU_en(s1_en),
        .SIGN(s1_SIGN_B),
        .EXPO(s1_EXPO_B),
        .FRAC(s1_FRAC_B)
    );

    Pipe_reg_1clk #(.W(3)) reg_rm_s0_s1(.clk(clk), .reset(reset), .D(rm), .Q(s1_rm));
    Pipe_reg_1clk #(.W(3)) reg_rm_s1_s2(.clk(clk), .reset(reset), .D(s1_rm), .Q(s2_rm));
    Pipe_reg_1clk #(.W(3)) reg_rm_s2_s3(.clk(clk), .reset(reset), .D(s2_rm), .Q(s3_rm));
    Pipe_reg_1clk #(.W(3)) reg_rm_s3_s4(.clk(clk), .reset(reset), .D(s3_rm), .Q(s4_rm));
    Pipe_reg_1clk #(.W(3)) reg_rm_s4_s5(.clk(clk), .reset(reset), .D(s4_rm), .Q(s5_rm));
    Pipe_reg_1clk #(.W(3)) reg_rm_s5_s6(.clk(clk), .reset(reset), .D(s5_rm), .Q(s6_rm));

    
    FADD_core #(.W(32))u_FADD_core(
        .clk(clk), .reset(reset),

        .s1_op(s1_op[0]),

        .s1_en(s1_en),
        .s1_SIGN_A(s1_SIGN_A),
        .s1_EXPO_A(s1_EXPO_A),
        .s1_FRAC_A(s1_FRAC_A),
        .s1_SIGN_B(s1_SIGN_B),
        .s1_EXPO_B(s1_EXPO_B),
        .s1_FRAC_B(s1_FRAC_B),

        .s6_error(s6_error_ADD),
        .s6_ADD_out(s6_ADD_out),
        .s6_rm(s6_rm),
        .s6_OF(s6_OF_ADD),
        .s6_UF(s6_UF_ADD)
    );

    FMUL_core #(.W(32))u_FMUL_core(
        .clk(clk), .reset(reset),

        .s1_en(s1_en),
        .s1_SIGN_A(s1_SIGN_A),
        .s1_EXPO_A(s1_EXPO_A),
        .s1_FRAC_A(s1_FRAC_A),
        .s1_SIGN_B(s1_SIGN_B),
        .s1_EXPO_B(s1_EXPO_B),
        .s1_FRAC_B(s1_FRAC_B),

        .s4_rm(s4_rm),

        .s6_MUL_out(s6_MUL_out),
        .s6_OF(s6_OF_MUL),
        .s6_UF(s6_UF_MUL)
    );
    Pipe_reg_1clk #(.W(2)) reg_op_s0_s1(.clk(clk), .reset(reset), .D(op), .Q(s1_op));
    Pipe_reg_1clk #(.W(1)) reg_op_s1_s2(.clk(clk), .reset(reset), .D(s1_op[1]), .Q(s2_op));
    Pipe_reg_1clk #(.W(1)) reg_op_s2_s3(.clk(clk), .reset(reset), .D(s2_op), .Q(s3_op));
    Pipe_reg_1clk #(.W(1)) reg_op_s3_s4(.clk(clk), .reset(reset), .D(s3_op), .Q(s4_op));
    Pipe_reg_1clk #(.W(1)) reg_op_s4_s5(.clk(clk), .reset(reset), .D(s4_op), .Q(s5_op));
    Pipe_reg_1clk #(.W(1)) reg_op_s5_s6(.clk(clk), .reset(reset), .D(s5_op), .Q(s6_op));

    MUX #(.W(32)) s6_u_mux(
        .ADD_out(s6_ADD_out),
        .MUL_out(s6_MUL_out),
        .op(s6_op),
        .OF_ADD(s6_OF_ADD),
        .UF_ADD(s6_UF_ADD),
        .error_ADD(s6_error_ADD),
        .OF_MUL(s6_OF_MUL),
        .UF_MUL(s6_UF_MUL),
        .OF(s6_OF),
        .UF(s6_UF),
        .ZF(s6_ZF),
        .sign(s6_sign),
        .error(s6_error),
        .Final_out(s6_final_out)
    );

    Pipe_reg_1clk #(.W(1)) reg_OF(.clk(clk), .reset(reset), .D(s6_OF), .Q(OF));
    Pipe_reg_1clk #(.W(1)) reg_sign(.clk(clk), .reset(reset), .D(s6_sign), .Q(sign));
    Pipe_reg_1clk #(.W(1)) reg_ZF(.clk(clk), .reset(reset), .D(s6_ZF), .Q(ZF));
    Pipe_reg_1clk #(.W(1)) reg_UF(.clk(clk), .reset(reset), .D(s6_UF), .Q(UF));
    Pipe_reg_1clk #(.W(1)) reg_error(.clk(clk), .reset(reset), .D(s6_error), .Q(error));

    Pipe_reg_1clk #(.W(32)) reg_FINAL_OUT(.clk(clk), .reset(reset), .D(s6_final_out), .Q(result_out));
endmodule