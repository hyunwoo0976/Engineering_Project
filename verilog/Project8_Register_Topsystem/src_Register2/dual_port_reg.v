module dual_port_reg #(parameter N=4)(
    input [N:0]din,
    input[1:0]r_add1,r_add2,w_add,
    input clk,reset,we,
    output [N-1:0]dout1,dout2
);  
    reg [N:0]mem[0:3];

    integer i;
    always @(posedge clk or posedge reset)begin
        if(reset)begin
            for(i=0;i<4;i=i+1)begin
                mem[i]<=0;
            end
        end else if(we)begin
                mem[w_add]<=din;
        end
    end
    assign dout1=mem[r_add1][N-1:0]; //[4:0]에서 [3:0]만 골라내기
    assign dout2=mem[r_add2][N-1:0];
endmodule    