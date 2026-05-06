module Top_module #(parameter W=32)(
    input [W-1:0]IN_A,IN_B,
    input [1:0]op,
    input clk,reset,
    output [W-1:0]result_out,
    output error,OF,UF
);
    wire [31:0]s1_IN_A,s1_IN_B;
    
    wire s1_SIGN_A,s1_SIGN_B;
    wire [7:0]s1_EXPO_A,s1_EXPO_B;
    wire [22:0]s1_FRAC_A,s1_FRAC_B;

    wire [31:0]ADD_out,MUL_out;
    wire [31:0]final_out;

    wire OF_ADD,OF_MUL,UF_ADD,UF_MUL,error_ADD;
    wire s6_OF, s6_UF, s6_error;
    wire s1_op, s2_op, s3_op, s4_op, s5_op, s6_op;


    Pipe_reg_1clk #(.W(32)) reg0_IN_A(.clk(clk), .reset(reset), .D(IN_A), .Q(s1_IN_A));
    Pipe_reg_1clk #(.W(32)) reg0_IN_B(.clk(clk), .reset(reset), .D(IN_B), .Q(s1_IN_B));

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

    FADD_core #(.W(32))FPU_ADD(
        .clk(clk), .reset(reset),
        .s6_ADD_out(ADD_out),
        .s6_OF(OF_ADD),
        .s6_UF(UF_ADD),
        .s6_error(error_ADD),
        .s1_SIGN_A(s1_SIGN_A),
        .s1_EXPO_A(s1_EXPO_A),
        .s1_FRAC_A(s1_FRAC_A),
        .s1_SIGN_B(s1_SIGN_B),
        .s1_EXPO_B(s1_EXPO_B),
        .s1_FRAC_B(s1_FRAC_B)
    );

    FMUL_core #(.W(32))FPU_MUL(
        .clk(clk), .reset(reset),
        .s6_MUL_out(MUL_out),
        .s6_OF(OF_MUL),
        .s6_UF(UF_MUL),
        .s1_SIGN_A(s1_SIGN_A),
        .s1_EXPO_A(s1_EXPO_A),
        .s1_FRAC_A(s1_FRAC_A),
        .s1_SIGN_B(s1_SIGN_B),
        .s1_EXPO_B(s1_EXPO_B),
        .s1_FRAC_B(s1_FRAC_B)
    );
    Pipe_reg_1clk #(.W(1)) reg_op_s0_s1(.clk(clk), .reset(reset), .D(op[1]), .Q(s1_op));
    Pipe_reg_1clk #(.W(1)) reg_op_s1_s2(.clk(clk), .reset(reset), .D(s1_op), .Q(s2_op));
    Pipe_reg_1clk #(.W(1)) reg_op_s2_s3(.clk(clk), .reset(reset), .D(s2_op), .Q(s3_op));
    Pipe_reg_1clk #(.W(1)) reg_op_s3_s4(.clk(clk), .reset(reset), .D(s3_op), .Q(s4_op));
    Pipe_reg_1clk #(.W(1)) reg_op_s4_s5(.clk(clk), .reset(reset), .D(s4_op), .Q(s5_op));
    Pipe_reg_1clk #(.W(1)) reg_op_s5_s6(.clk(clk), .reset(reset), .D(s5_op), .Q(s6_op));

    MUX #(.W(32))final_mux(
        .ADD_out(ADD_out),
        .MUL_out(MUL_out),
        .op(s6_op),
        .OF_ADD(OF_ADD),
        .UF_ADD(UF_ADD),
        .error_ADD(error_ADD),
        .OF_MUL(OF_MUL),
        .UF_MUL(UF_MUL),
        .OF(s6_OF),
        .UF(s6_UF),
        .error(s6_error),
        .Final_out(final_out)
    );
    Pipe_reg_1clk #(.W(1)) reg_OF(.clk(clk), .reset(reset), .D(s6_OF), .Q(OF));
    Pipe_reg_1clk #(.W(1)) reg_UF(.clk(clk), .reset(reset), .D(s6_UF), .Q(UF));
    Pipe_reg_1clk #(.W(1)) reg_error(.clk(clk), .reset(reset), .D(s6_error), .Q(error));

    Pipe_reg_1clk #(.W(32)) reg_FINAL_OUT(.clk(clk), .reset(reset), .D(final_out), .Q(result_out));
endmodule

    


    



    