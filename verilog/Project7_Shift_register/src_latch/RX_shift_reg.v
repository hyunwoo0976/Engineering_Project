module RX_shift_reg #(parameter W=32)(
    input N,
    input clk,reset,shift,
    output reg [W-1:0]D_out
);

    always @(posedge clk or posedge reset)begin
        if(reset)begin
            D_out<=0;
        end 
        else if(shift)begin
            D_out<={N,D_out[W-1:1]};
        end
    end
endmodule