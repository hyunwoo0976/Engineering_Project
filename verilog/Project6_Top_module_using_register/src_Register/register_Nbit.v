module register_Nbit #(parameter N=4)(
    input clk,
    input reset,
    input [N:0]d,
    output reg [N:0] q
);

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            q <=0;
        end else begin
            q <=d;
        end
    end
endmodule
