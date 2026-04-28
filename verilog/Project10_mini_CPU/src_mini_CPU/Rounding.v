module Rounding #(parameter W=48)(
    input [W-1:0] FRAC,
    output [22:0] final_FRAC,
    output count,
    output reg doing,direction,
    output error
);
    wire LSB=FRAC[24];
    wire G=FRAC[23];
    wire R=FRAC[22];
    wire S=|FRAC[21:0];
    
    wire round_up=G&(R|S|LSB);

    wire [24:0]rounded_top=FRAC[47:24]+round_up;

    wire overflow=rounded_top[24]; 
    assign count=overflow; 

    always@(*)begin
        if(count)begin
            doing=1;
            direction=0;
        end
        else begin
            doing=0;
            direction=0;
        end
    end

    assign final_FRAC=overflow ? rounded_top[23:1]:rounded_top[22:0];
    assign error=(~overflow)&(rounded_top[23]==1'b0);
endmodule