module Normalization_Controller#(parameter W=32)(
    input [W-1:0]Sum,
    input Cout,
    input eff_sub,
    output reg [7:0]count,
    output reg direction,doing,
    output [W:0]nor_FRAC
);
    wire [5:0]lzd_count;
    wire all_zero;

    assign nor_FRAC={Cout,Sum};

    LZD #(.W(W))lzd(
        .Sum(Sum),
        .count(lzd_count),
        .all_zero(all_zero)
    );

    always @(*)begin
        count=0;
        direction=0;
        doing=0;
        if(eff_sub)begin
            if(all_zero)begin
                doing=0;
                direction=0;
                count=0;
            end
            else begin
                count={2'b0, lzd_count};
                direction=0;
                doing=1;
            end
        end
        else begin
            if(Cout)begin
                count=8'd1;
                direction=1;
                doing=1;
            end
            else begin
                doing=0;
                direction=0;
                count=0;
            end
        end
    end
endmodule