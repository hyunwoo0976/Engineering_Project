module FPU_unpack #(parameter W=32)(
    input [W-1:0]IN,
    input FPU_en,
    output SIGN,
    output [7:0]EXPO,
    output [22:0]FRAC
);
    assign SIGN=(FPU_en) ? IN[W-1] : 1'd0;
    assign EXPO=(FPU_en) ? IN[W-2 -:8] : 8'd0;
    assign FRAC=(FPU_en) ? IN[W-10:0] : 23'd0;
    
endmodule