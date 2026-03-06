module dual_port_reg(
    input clk, reset,we,
    input [1:0] w_add,
    input [1:0] r_add1,r_add2,
    input [3:0] din,
    output [3:0] dout1,dout2
);

    reg [3:0]mem[0:3];

    integer i;
    always @(posedge clk or posedge reset) begin
        if(reset)begin
            for(i=0;i<4;i=i+1)begin
                mem[i]<=4'b0000;
            end 
            else if(we)begin
                mem[w_add]<=din;
            end
        end
    end
    assign dout1=mem[r_add1];
    assign dout2=mem[r_add2];
endmodule