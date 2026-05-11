module Pipe_reg_1clk_en #(parameter W=32)(
    input [W-1:0]D,
    input clk,reset,en,
    output reg [W-1:0]Q
);
    wire gated_clk=clk&en;

    always@(posedge gated_clk or posedge reset)begin
        if(reset)begin
            Q<=0;
        end
        else begin
            Q<=D;
        end
    end
endmodule