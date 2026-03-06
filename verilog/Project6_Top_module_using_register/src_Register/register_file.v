module register_file(
    input [3:0] din,
    input clk, reset,
    input we,
    input [1:0]add,
    output [3:0] dout
);
    reg [3:0] mem[0:3];

    integer i;

    always @(posedge clk or posedge reset) begin
        if(reset)begin
            for(i=0;i<4;i=i+1)begin
                mem[i]<=4'b0000;
            end
        end else if (we) begin
            mem[add]<=din;
        end
    end
    assign dout=mem[add];
endmodule
