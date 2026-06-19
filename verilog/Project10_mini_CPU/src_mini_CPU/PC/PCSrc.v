module PCSrc (
    input ZF,sign,
    input is_BEQ, is_BNE, is_BLT, is_BGE,
    output PCSrc
);

    assign PCSrc = (ZF & is_BEQ) || (!ZF & is_BNE) || (sign & is_BLT) || (!sign & is_BGE);
    
endmodule