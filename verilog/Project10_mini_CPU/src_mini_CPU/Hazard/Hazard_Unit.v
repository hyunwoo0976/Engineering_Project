module Hazard_Unit (
    input clk, reset,
    input ID_PCSrc, EX_PCSrc,
    input ID_is_FPU, EX_is_FPU, EX_is_FLW, ID_is_FSW,
    input EX_MemRead, ID_RegWrite,
    input EX_is_JALR,
    input [4:0]EX_Rd, ID_Rs1,ID_Rs2,
    output IF_ID_flush, ID_EX_flush,
    output PCWrite,
    output IF_ID_stall, ID_EX_stall,
    output FPU_Valid, Rs1, Rs2
);  
    wire CPU_IF_ID_stall, CPU_ID_EX_stall;
    wire FPU_IF_ID_stall, FPU_ID_EX_stall;
    wire CPU_ID_EX_flush, FPU_ID_EX_flush;
    
    wire CPU_PCWrite, FPU_PCWrite;

    CPU_Hazard u_CPU_Hazard(
        .ID_PCSrc(ID_PCSrc), .EX_PCSrc(EX_PCSrc),
        .EX_MemRead(EX_MemRead), .ID_RegWrite(ID_RegWrite),
        .EX_is_JALR(EX_is_JALR),
        .EX_Rd(EX_Rd), .ID_Rs1(ID_Rs1), .ID_Rs2(ID_Rs2),
        .IF_ID_flush(IF_ID_flush), .ID_EX_flush(CPU_ID_EX_flush),
        .IF_ID_stall(CPU_IF_ID_stall), .ID_EX_stall(CPU_ID_EX_stall),
        .PCWrite(CPU_PCWrite)
    );

    FPU_Hazard u_FPU_Hazard(
        .clk(clk), .reset(reset),
        .ID_is_FPU(ID_is_FPU), .EX_is_FPU(EX_is_FPU), .EX_is_FLW(EX_is_FLW), .ID_is_FSW(ID_is_FSW),
        .EX_Rd(EX_Rd), .ID_Rs1(ID_Rs1), .ID_Rs2(ID_Rs2),
        .FPU_Valid(FPU_Valid), .Rs1(Rs1), .Rs2(Rs2),
        .IF_ID_stall(FPU_IF_ID_stall), .ID_EX_stall(FPU_ID_EX_stall),
        .ID_EX_flush(FPU_ID_EX_flush),
        .PCWrite(FPU_PCWrite)
    );

    Hazard_Combine u_Hazard_Combine(
        .CPU_IF_ID_stall(CPU_IF_ID_stall), .CPU_ID_EX_stall(CPU_ID_EX_stall),
        .FPU_IF_ID_stall(FPU_IF_ID_stall), .FPU_ID_EX_stall(FPU_ID_EX_stall),

        .CPU_ID_EX_flush(CPU_ID_EX_flush), .FPU_ID_EX_flush(FPU_ID_EX_flush),
        .CPU_PCWrite(CPU_PCWrite), .FPU_PCWrite(FPU_PCWrite),

        .IF_ID_stall(IF_ID_stall), .ID_EX_stall(ID_EX_stall),
        .ID_EX_flush(ID_EX_flush),

        .PCWrite(PCWrite)
    );
endmodule