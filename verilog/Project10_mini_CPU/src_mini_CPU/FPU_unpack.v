module FPU_unpack #(parameter W=32)(
    input [W-1:0]IN,
    output SIGN,
    output [7:0]EXPO,
    output [22:0]FRAC
);
    assign SIGN=IN[W-1];
    assign EXPO=IN[W-2 -:8];
    assign FRAC=IN[W-10:0];
    
endmodule