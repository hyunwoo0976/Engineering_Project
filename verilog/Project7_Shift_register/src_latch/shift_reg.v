module shift_reg #(parameter W=4)(
    input [W-1:0]D_a,
    input clk,reset,load,
    output reg [W-1:0]Q_a,
    output reg N
);

    always @(posedge clk or posedge reset) begin
        if(reset)begin
            Q_a<=0;
        end
        else begin
            if(load)begin
                Q_a<=D_a;
            end
            else begin
                N<=Q_a[0];
                Q_a<={1'b0,Q_a[W-1:1]};
            end
        end      
    end
endmodule