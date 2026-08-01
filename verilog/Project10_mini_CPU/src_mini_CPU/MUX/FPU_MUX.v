module FPU_MUX #(parameter W = 32)(
    input [W-1:0] FPU_Result,
    input FPU_Valid,
    output reg [W-1:0]EX_FPU_Result
);

    always @(*)begin
        if(FPU_Valid)begin
            EX_FPU_Result = FPU_Result;
        end
        else begin
            EX_FPU_Result = {W{1'b0}};
        end
    end
endmodule