module m_register #(parameter W=4)(
    input clk,reset,we,
    input [1:0]w_add,r_add1,r_add2,
    input [W-1:0]din,
    output [W-1:0]dout1,dout2
);
    reg [W-1:0]mem[0:3];

    integer i;
    always @(posedge clk or posedge reset)begin
        if(reset)begin
            for(i=0;i<3;i=i+1)begin
                mem[i]<=0;
            end
        end 
        else if(we)begin
                mem[w_add]<=din;
        end
    end

    assign dout1=mem[r_add1];
    assign dout2=mem[r_add2];

    
endmodule