module Final_MUX #(parameter W = 32)(
    input special,
    input [W-1:0] Final_out,
    input [W-1:0] result,

    output [W-1:0] Answer
);

    assign Answer = (special) ? result : Final_out;
endmodule
