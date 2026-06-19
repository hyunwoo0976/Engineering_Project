module ALU_B_MUX #(parameter W=32)(
    input ALUsrc,
    input Forward,
    input [W-1:0]Imm,
    input [W-1:0]B,
    output reg [W-1:0]ALU_in_b
);
    always @(*)begin
        if(ALUsrc)begin
            ALU_in_b = Imm;
        end
        else if(Forward)begin
            ALU_in_b = 32'd4;
        end
        else begin
            ALU_in_b = B;
        end
    end
endmodule