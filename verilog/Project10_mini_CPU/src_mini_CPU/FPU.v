module FPU #(parameter W=32)(
    input [W-1:0]IN_a,IN_b,
    input mode,clk,reset,
    output [W-1:0]result_out
);
    wire SIGN_a,SIGN_b;
    wire [7:0]EXPO_a,EXPO_b;
    wire [23:0]FRAC_a,FRAC_b;
    

    FPU_unpack unpack_A(
        .IN(IN_a),
        .SIGN(SIGN_a),
        .EXPO(EXPO_a),
        .FRAC(FRAC_a)
    );

    FPU_unpack unpack_B(
        .IN(IN_b),
        .SIGN(SIGN_b),
        .EXPO(EXPO_b),
        .FRAC(FRAC_b)
    );



