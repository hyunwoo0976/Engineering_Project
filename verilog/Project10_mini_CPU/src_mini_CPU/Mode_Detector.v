module Mode_Detector (
    input sign_A,
    input sign_B,
    input mode,
    output eff_sub
);
    assign eff_sub = sign_A ^ sign_B ^ mode;
    
endmodule