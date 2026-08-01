module EXPO_MUX #(parameter W=9)(
    input [W-1:0]EXPO_in,
    input count,
    input EXPO_break,
    output [W-1:0]EXPO_out
);
    wire [W-1:0]EXPO_plus=EXPO_in+1'b1;
    wire [W-1:0]EXPO_temt;

    assign EXPO_temt=(count==1'b1) ? EXPO_plus : EXPO_in;
    assign EXPO_out = (EXPO_break) ? {W{1'b0}} : EXPO_temt;
endmodule