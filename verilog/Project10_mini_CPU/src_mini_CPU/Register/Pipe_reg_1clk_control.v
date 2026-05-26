module Pipe_reg_1clk_control #(parameter W=32)(
    input clk,reset,
    input stall,    //0: Pass 1: Hold data
    input flush,    //1: Clear data
    input [W-1:0]D,
    output reg [W-1:0]Q
);

    always @(posedge clk or posedge reset)begin
        if(reset || flush)begin
            Q<=0;
        end
        else if(!stall)begin
            Q<=D;
        end
    end
endmodule