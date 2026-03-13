module Top_register #(parameter W=32)(
    input clk,reset,shift,load,
    input [W-1:0] D_in,
    output [W-1:0] D_out,
    output fin
);
    wire N;

    TX_shift_reg #(.W(W))reg0(
        .clk(clk),.reset(reset),.shift(shift),.load(load),
        .D_in(D_in),.N(N),.fin(fin)
    );

    RX_shift_reg #(.W(W))reg1(
        .clk(clk),.reset(reset),.shift(shift),
        .D_out(D_out),.N(N)
    );
endmodule