module MUL_EXPO_ADD(
    input [7:0]EXPO_A,EXPO_B,
    output [8:0] EXPO_ADD
);

    assign EXPO_ADD=EXPO_A+EXPO_B;
endmodule