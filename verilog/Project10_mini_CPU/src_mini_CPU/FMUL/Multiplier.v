module Multiplier #(parameter W=48)(
    input [W/2-1:0] FRAC_A,FRAC_B,
    output [W-1:0] FRAC_mul
);

    assign FRAC_mul=FRAC_A*FRAC_B;
endmodule