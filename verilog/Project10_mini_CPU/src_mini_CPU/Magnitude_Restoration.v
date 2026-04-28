module Magnitude_Restoration #(parameter W=32)(
    input [W-1:0]Sum,
    input eff_sub,
    input Cout,
    output reg [W-1:0]SUM
);
    always@(*)begin
        if(eff_sub==1'b1)begin
            if(Cout==1'b0)begin
                SUM=~Sum+1'b1;
            end
            else begin
                SUM=Sum;
            end
        end
        else begin
            SUM=Sum;
        end
    end
endmodule

