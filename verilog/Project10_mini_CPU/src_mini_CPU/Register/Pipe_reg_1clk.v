module Pipe_reg_1clk #(parameter W=32)(
    input [W-1:0]D,
    input clk,reset,
    output reg [W-1:0]Q
);

    always @(posedge clk or posedge reset)begin
        if(reset)begin
            Q<=0;
        end
        else begin
            Q<=D;
        end
    end
endmodule