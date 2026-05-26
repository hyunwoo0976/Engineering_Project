module PCSrc (
    input ZF,
    input is_BEQ,
    output PCSrc
);
    assign PCSrc = ZF & is_BEQ;
endmodule