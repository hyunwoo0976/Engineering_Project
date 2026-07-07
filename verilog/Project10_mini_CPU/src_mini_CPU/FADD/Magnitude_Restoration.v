module Magnitude_Restoration #(parameter W=48)(
    input [W-1:0]Sum_1,Sum_2,
    input cout_1,
    input eff_sub,
    output reg [W-1:0]SUM,
    output reg Cout
);
    always @(*) begin
    if (eff_sub == 1'b1) begin
        Cout = 1'b0;
        if (cout_1 == 1'b1) begin
            SUM = Sum_1; // A >= B

        end
        else begin
            SUM = Sum_2; // A < B
        end
    end
    else begin
        SUM = Sum_1; 
        Cout = cout_1;
    end
end
endmodule

