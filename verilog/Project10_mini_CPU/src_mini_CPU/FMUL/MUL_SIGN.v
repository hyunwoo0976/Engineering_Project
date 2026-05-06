module MUL_SIGN(
    input SIGN_A,SIGN_B,
    output SIGN
);

    assign SIGN=SIGN_A^SIGN_B;
endmodule