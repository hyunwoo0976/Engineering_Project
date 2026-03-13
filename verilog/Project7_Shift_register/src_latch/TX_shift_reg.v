module TX_shift_reg #(parameter W=32)(
    input [W-1:0]D_in,
    input clk,reset,load,shift,
    output N,fin
);
    reg [5:0]count;
    reg [W-1:0]Q_a;
    assign N=Q_a[0];
    assign fin=(count==32)?1'b1:1'b0;

    always @(posedge clk or posedge reset) begin
        if(reset)begin
            Q_a<=0;
        end
        else if(load)begin
            Q_a<=D_in;
        end
        else if(shift)begin
            Q_a<={1'b0,Q_a[W-1:1]};
        end
    end
    always @(posedge clk or posedge reset) begin
        if(reset)begin
            count<=0;
        end
        else if(load)begin
            count<=0;
        end
        else if(shift)begin
            count<=count+1;
        end
    end
    
endmodule