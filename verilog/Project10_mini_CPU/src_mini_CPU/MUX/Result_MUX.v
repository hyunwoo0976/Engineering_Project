module Result_MUX #(parameter W=32)(
    input [W-1:0]ALU_Result,
    input [W-1:0]FPU_Result,
    input FPU_Valid,
    output [W-1:0]Result
);
    assign Result = (FPU_Valid) ? FPU_Result : ALU_Result;
endmodule