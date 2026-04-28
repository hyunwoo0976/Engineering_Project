module Cond_Inverter #(parameter W=32)(
    input eff_sub,
    input [W-1:0]FRAC_B,
    output reg [W-1:0]FRAC_cla_B,
    output reg Cin
);
    always @(*)begin
        if(eff_sub)begin
            FRAC_cla_B=~FRAC_B;
            Cin=1'b1;
        end
        else begin
            FRAC_cla_B=FRAC_B;
            Cin=1'b0;
        end
    end
endmodule
