module Pipe_reg_2clk #(parameter W=8)(
    input [W-1:0]D,
    input clk,reset,
    output reg [W-1:0]Q
);

    reg [W-1:0] delay_pipe[0:0];
    
    integer i;
    always @(posedge clk or posedge reset)begin
        if(reset)begin
            delay_pipe[0]<=0;
            Q<=0;
        end 
        else begin
            delay_pipe[0]<=D;
            Q<=delay_pipe[0];
        end
    end
endmodule