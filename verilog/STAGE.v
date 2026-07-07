module STAGE #(parameter STAGE_COUNT = 7)(
    input Stage_in,
    input clk, reset,
    output reg [STAGE_COUNT:1] s
);
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            s <= {STAGE_COUNT{1'b0}};
        end
        else begin
            s[1] <= Stage_in;
            s[STAGE_COUNT:2] <= s[STAGE_COUNT-1:1]; 
        end
    end
endmodule