module d_latch (
    input d,
    input en,      
    input reset,
    output reg q
);
    always @(*) begin 
        if (reset) begin
            q <= 1'b0;
        end 
        else if (en) begin
            q <= d; 
        end
    end
endmodule