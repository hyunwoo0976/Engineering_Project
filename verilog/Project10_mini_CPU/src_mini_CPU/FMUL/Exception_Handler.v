module Exception_Handler #(parameter W=32)(
    input OF, UF,
    input SIGN,
    input [7:0]EXPO,
    input [22:0]FRAC,
    output [W-1:0]result_out
);

    assign result_out= (OF || UF) ? {SIGN, EXPO, 23'b0} : {SIGN,EXPO,FRAC};
endmodule