module Exception_Handler #(parameter W=32)(
    input SIGN,
    input [7:0]EXPO,
    input [22:0]FRAC,
    output [W-1:0]result_out
);

    assign result_out={SIGN,EXPO,FRAC};
endmodule