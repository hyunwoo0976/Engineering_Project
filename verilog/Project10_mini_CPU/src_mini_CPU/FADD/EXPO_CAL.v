module EXPO_CAL #(parameter W=9)(
    input [W-1:0] EXPO_in,
    input [5:0] count,
    input direction,
    input doing,
    output reg [W-1:0] EXPO_out
);
    always @(*) begin
        if (doing == 1'b0) begin
            EXPO_out = EXPO_in;
        end
        else begin
            if (direction) begin
                EXPO_out = EXPO_in + 9'd1;
            end
            else begin
                EXPO_out = EXPO_in - {3'b0, count}; 
            end
        end
    end
endmodule