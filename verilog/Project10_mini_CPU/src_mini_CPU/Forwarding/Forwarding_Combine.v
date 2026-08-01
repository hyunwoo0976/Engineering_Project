module Forwarding_Combine(
    input EX_is_FPU, EX_is_FLW, EX_is_FSW,
    input [1:0]CPU_MEMtoEX_forward, CPU_WBtoEX_forward,
    input [1:0]FPU_MEMtoEX_forward, FPU_WBtoEX_forward,
    output [1:0]MEMtoEX_forward, WBtoEX_forward
);
    wire is_FPU;
    assign is_FPU = (EX_is_FPU || EX_is_FLW || EX_is_FSW) ? 1'b1 : 1'b0;

    assign MEMtoEX_forward = (is_FPU) ? FPU_MEMtoEX_forward : CPU_MEMtoEX_forward;
    assign WBtoEX_forward = (is_FPU) ? FPU_WBtoEX_forward : CPU_WBtoEX_forward;
endmodule
