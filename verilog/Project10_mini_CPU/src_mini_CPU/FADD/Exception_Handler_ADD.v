module Exception_Handler_ADD(
    input SIGN,
    input [8:0] EXPO,
    input [22:0] FRAC,
    output reg overflow_flag,
    output reg underflow_flag,
    output reg [31:0] final_result
);
    always @(*) begin
        overflow_flag = 1'b0;
        underflow_flag = 1'b1;
        final_result = 32'b0;
        if (EXPO >= 9'd255) begin
            final_result = {SIGN, 8'hFF, 23'h0};
            overflow_flag = 1'b1;
            underflow_flag = 1'b0;
        end
        else if (EXPO[8] == 1'b1 || EXPO == 9'd0) begin
            final_result = {SIGN, 8'h00, 23'h0};
            overflow_flag = 1'b0;
            underflow_flag = 1'b1;
        end
        else begin
            final_result = {SIGN, EXPO[7:0], FRAC};
            overflow_flag = 1'b0;
            underflow_flag = 1'b0;
        end
    end
endmodule