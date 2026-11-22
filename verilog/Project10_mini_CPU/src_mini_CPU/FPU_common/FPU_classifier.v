module FPU_classifier #(parameter W = 32)(
    input SIGN,
    input[7:0]EXPO,
    input[22:0]FRAC,
    input FPU_en,

    output reg is_Pzero, is_Nzero,
    output is_subnormal, is_normal,
    output is_inf, is_nan,

    output hidden_bit, effective_exponent
);
    wire temp_zero;

    assign temp_zero = (EXPO == 0 && FRAC == 0) ? 1'b1 : 1'b0;
    assign temp_subnormal = (EXPO == 0 && FRAC != 0) ? 1'b1 : 1'b0;

    always @(*) begin
        hidden_bit = 1'b1;
        
        if(temp_zero)begin
            {is_Nzero, is_Pzero} = 2'b00;
            hidden_bit = 1'b0;
            if(SIGN)begin
                is_Nzero = 1'b1;
            end
            else begin
                is_Pzero = 1'b1;
            end
        end
        else begin
            {is_Nzero, is_Pzero} = 2'b00;
        end

        if(temp_subnormal)begin
            
        end
    end

endmodule
    
