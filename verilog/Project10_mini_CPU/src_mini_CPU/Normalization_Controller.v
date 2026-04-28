module Normalization_Controller#(parameter W=32)(
    input [W-1:0]Sum,
    input Cout,
    output reg [5:0]count,
    output reg direction,doing,
    output [W:0]nor_FRAC
);
    wire [5:0]lzd_count;
    wire all_zero;

    assign nor_FRAC={Cout,Sum};

    LZD #(.W(W))lzd(
        .Sum(Sum),
        .Cout(Cout),
        .count(lzd_count),
        .all_zero(all_zero)
    );

    always @(*)begin
        if(all_zero)begin
            count=0;
            direction=0;
            doing=0;
        end
        else begin
            if(Cout)begin
                count=1;
                direction=1;
                doing=1;
            end
            else begin
                count=lzd_count;
                direction=0;
                doing=1;
            end
        end
    end
endmodule