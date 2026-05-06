module SIGN(
    input SIGN_A,SIGN_B,
    input mode,bigger,
    output reg result_SIGN
);
    always @(*) begin
        if (mode == 1'b1) begin
            if (SIGN_A != SIGN_B) begin
                result_SIGN = SIGN_A;
            end 
            else begin
                result_SIGN = (bigger) ? SIGN_A : ~SIGN_A; 
            end
        end 
        else begin 
            if (SIGN_A == SIGN_B) begin
                result_SIGN = SIGN_A;
            end 
            else begin
                result_SIGN = (bigger) ? SIGN_A : SIGN_B;
            end
        end
    end
endmodule