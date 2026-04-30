module Normalization_MUL #(parameter W=48)(
    input [W-1:0] FRAC_mul,
    output [22:0]FRAC_out,
    output reg count,
    output round_carry
);
    reg [22:0]FRAC_etc;
    reg L,G,S;
    wire round_up;
    wire [23:0] rounded_FRAC=FRAC_etc+round_up;


    always @(*)begin
        if(FRAC_mul[47]==1'b1)begin
            FRAC_etc=FRAC_mul[46:24];
            count=1;
            L=FRAC_etc[0];
            G=FRAC_mul[23];
            S=|FRAC_mul[22:0];
        end
        else begin
            FRAC_etc=FRAC_mul[45:23];
            count=0;
            L=FRAC_etc[0];
            G=FRAC_mul[22];
            S=|FRAC_mul[21:0];
        end
    end

    assign round_up=G&(S|L);
    assign FRAC_out=rounded_FRAC[22:0];
    assign round_carry=rounded_FRAC[23];
endmodule