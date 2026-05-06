module EXPO_MUX #(parameter W=9)(
    input [W-1:0]EXPO_in,
    input count,
    output [W-1:0]EXPO_out
);
    wire [W-1:0]EXPO_plus=EXPO_in+1'b1;

    assign EXPO_out=(count==1'b1) ? EXPO_plus : EXPO_in;
endmodule