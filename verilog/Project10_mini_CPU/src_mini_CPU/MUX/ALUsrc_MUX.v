module ALUsrc_MUX #(parameter W=32)(
    input ALUsrc,
    input [W-1:0]Imm,
    input [W-1:0]B,
    output [W-1:0]ALU_in_b
);
    assign ALU_in_b = (ALUsrc) ? Imm : B;
endmodule