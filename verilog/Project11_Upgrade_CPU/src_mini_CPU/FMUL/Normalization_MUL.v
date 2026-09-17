`default_nettype none
// A 24x24 product has its binary point below bit 46.
// Normalize to hidden bit 47, then denormalize if the exponent is below 1.
module Normalization_MUL #(
    parameter W = 48
) (
    input wire [W-1:0] FRAC_mul,
    input wire signed [11:0] EXPO_base,
    output reg [47:0] FRAC_out,
    output reg [8:0] EXPO_out
);
    integer i, leading, deficit;
    reg found, sticky;
    reg signed [11:0] e;
    reg [47:0] normalized;
    always @(*)begin
        leading = 0;
        found = 0;
        sticky = 0;
        deficit = 0;
        for(i = 47; i >= 0; i = i - 1)begin
            if(!found && FRAC_mul[i])begin
                leading = 47 - i;
                found = 1;
            end
        end
        normalized = FRAC_mul << leading;
        e = EXPO_base + 12'sd1 - leading;
        FRAC_out = normalized;
        EXPO_out = 9'd1;
        if(!found) FRAC_out = 0;
        else if(e < 1)begin
            deficit = 1 - e;
            FRAC_out = normalized >> deficit;
            for(i = 0; i < 48; i = i + 1) if(i < deficit) sticky = sticky | normalized[i];
            FRAC_out[0] = FRAC_out[0] | sticky;
        end
        else EXPO_out = e[8:0];
    end
endmodule
`default_nettype wire
