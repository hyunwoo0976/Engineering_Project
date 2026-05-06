module comparator(
    input [7:0] EXPO_A,EXPO_B,
    input [22:0]FRAC_A,FRAC_B,
    output bigger
);
    wire [30:0]mag_a={EXPO_A,FRAC_A};
    wire [30:0]mag_b={EXPO_B,FRAC_B};

    assign bigger= (mag_a>=mag_b)?1'b0:1'b1;
endmodule