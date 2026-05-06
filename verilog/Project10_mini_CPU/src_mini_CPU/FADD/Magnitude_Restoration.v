module Magnitude_Restoration #(parameter W=48)(
    input [W-1:0]Sum_1,Sum_2,
    input cout_1,
    input eff_sub,
    output [W-1:0]SUM
);
    assign SUM=(cout_1==1'b1)?Sum_1:Sum_2;
endmodule

