module FPU_classifier(
    input SIGN,
    input [7:0] EXPO,
    input [22:0] FRAC,

    output reg is_Pzero, is_Nzero,
    output is_zero,
    output is_subnormal, is_normal, is_inf, is_nan, is_snan,

    output hidden_bit,
    output [7:0] effective_exponent
);
    assign is_zero = (EXPO == 0) && (FRAC == 0);

    always @(*)begin
        {is_Nzero, is_Pzero} = 2'b00;
        if(is_zero)begin
            if(SIGN)begin
                is_Nzero = 1'b1;
            end
            else begin
                is_Pzero = 1'b1;
            end
        end
    end

    assign is_subnormal = (EXPO == 0) && (FRAC != 0);
    assign is_normal = (EXPO != 0) && (EXPO != 255);
    assign is_inf = (EXPO == 255) && (FRAC == 0);
    assign is_nan = (EXPO == 255) && (FRAC != 0);
    assign is_snan = is_nan && !FRAC[22];
    assign hidden_bit = is_normal;
    assign effective_exponent = (EXPO == 0) ? 8'd1 : EXPO;

endmodule
