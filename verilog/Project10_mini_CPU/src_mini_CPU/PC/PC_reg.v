module PC_reg #(parameter W=32)(
    input clk, reset,
    input PCWrite,
    input [W-1:0]next_pc,
    output reg [W-1:0]pc
);
    always @(posedge clk or posedge reset)begin
        if(reset)begin
            pc<=32'b0;
        end
        else if(PCWrite)begin
            pc<=next_pc;
        end
    end
endmodule