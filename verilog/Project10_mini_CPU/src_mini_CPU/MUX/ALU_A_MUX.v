module ALU_A_MUX #(parameter W=32)(
    input [W-1:0]EX_A,
    input [W-1:0]pc,
    input is_JALR,
    output reg [W-1:0]EX_ALU_in_a
);
    always @(*)begin
        if(is_JALR)begin
            EX_ALU_in_a = pc;
        end
        else begin
            EX_ALU_in_a = EX_A;
        end
    end
endmodule
