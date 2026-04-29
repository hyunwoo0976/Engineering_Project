module Pipe_reg_3clk #(parameter W = 8) (
    input [W-1:0] D,
    input clk, reset,
    output reg [W-1:0] Q
);
    reg [W-1:0] delay_pipe [1:0];
    
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for(i=0; i<2; i=i+1) begin
                delay_pipe[i] <= 0;
            end
            Q<=0; 
        end 
        else begin
            delay_pipe[0] <= D;
            delay_pipe[1] <= delay_pipe[0];
            Q <= delay_pipe[1];
        end
    end
endmodule