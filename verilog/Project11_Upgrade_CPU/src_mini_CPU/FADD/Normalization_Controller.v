module Normalization_Controller #(parameter W = 32)(
    input [W-1:0] Sum,
    input Cout,
    input eff_sub,
    input [7:0] EXPO_in,  // effective biased exponent, minimum 1
    output reg [7:0] count,
    output reg direction, doing,
    output [W:0] nor_FRAC,
    output reg EXPO_break
);
    wire [5:0] lzd_count;
    wire all_zero;

    assign nor_FRAC = {Cout, Sum};

    LZD #(.W(W)) lzd(
        .Sum(Sum),
        .count(lzd_count),
        .all_zero(all_zero)
    );

    always @(*)begin
        count = 8'b0;
        direction = 1'b0;
        doing = 1'b0;
        EXPO_break = 1'b0;
        if(all_zero && !Cout)begin
            doing = 0;
            direction = 0;
            count = 0;
            EXPO_break = 1'b1;
        end
        else if(Cout && !eff_sub)begin
            count = 8'd1;
            direction = 1;
            doing = 1;
        end
        else begin
            // Stop at effective exponent 1, including sums of subnormals.
            count = (lzd_count < EXPO_in) ? {2'b0, lzd_count} : EXPO_in - 8'd1;
            direction = 0;
            doing = (count != 0);
        end
    end
endmodule
