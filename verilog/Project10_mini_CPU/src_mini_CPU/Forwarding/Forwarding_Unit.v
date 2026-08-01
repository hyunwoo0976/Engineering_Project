module Forwarding_Unit #(parameter W=32)(
    input MEM_RegWrite, WB_RegWrite,
    input MEM_FRegWrite, WB_FRegWrite,
    input EX_is_FPU, EX_is_FLW, EX_is_FSW,
    input EX_uses_Rs1, EX_uses_Rs2,
    input EX_uses_FRs1, EX_uses_FRs2, 
    input [4:0] MEM_Rd, WB_Rd,
    input [4:0] EX_Rs1, EX_Rs2,
    output reg [1:0] MEMtoEX_forward,
    output reg [1:0] WBtoEX_forward
);
    wire [1:0]CPU_MEMtoEX_forward, FPU_MEMtoEX_forward;
    wire [1:0]CPU_WBtoEX_forward, FPU_WBtoEX_forward;

    CPU_Forwarding_Unit #(.W(W))u_CPU_Forwarding_Unit(
        .MEM_RegWrite(MEM_RegWrite), .WB_RegWrite(WB_RegWrite),
        .MEM_Rd(MEM_Rd), .WB_Rd(WB_Rd),
        .EX_Rs1(EX_Rs1), .EX_Rs2(EX_Rs2),
        .EX_uses_Rs1(EX_uses_Rs1), .EX_uses_Rs2(EX_uses_Rs2),
        .MEMtoEX_forward(CPU_MEMtoEX_forward), .WBtoEX_forward(CPU_WBtoEX_forward)
    );

    FPU_Forwarding_Unit #(.W(W))u_FPU_Forwarding_Unit(
        .MEM_RegWrite(MEM_RegWrite), .WB_RegWrite(WB_RegWrite),
        .MEM_FRegWrite(MEM_FRegWrite), .WB_FRegWrite(WB_FRegWrite),
        .MEM_Rd(MEM_Rd), .WB_Rd(WB_Rd),
        .EX_Rs1(EX_Rs1), .EX_Rs2(EX_Rs2),
        .EX_uses_Rs1(EX_uses_Rs1), .EX_uses_Rs2(EX_uses_Rs2),
        .EX_uses_FRs1(EX_uses_FRs1), .EX_uses_FRs2(EX_uses_FRs2),
        .MEMtoEX_forward(FPU_MEMtoEX_forward), .WBtoEX_forward(FPU_WBtoEX_forward)
    );

    Forwarding_Combine u_Forwarding_Combine(
        .EX_is_FPU(EX_is_FPU), .EX_is_FLW(EX_is_FLW), .EX_is_FSW(EX_is_FSW),
        .CPU_MEMtoEX_forward(CPU_MEMtoEX_forward), .CPU_WBtoEX_forward(CPU_WBtoEX_forward),
        .FPU_MEMtoEX_forward(FPU_MEMtoEX_forward), .FPU_WBtoEX_forward(FPU_WBtoEX_forward),
        .MEMtoEX_forward(MEMtoEX_forward), .WBtoEX_forward(WBtoEX_forward)
    );

endmodule
