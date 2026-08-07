module Hazard_Combine(
    input CPU_IF_ID_stall, CPU_ID_EX_stall,
    input FPU_IF_ID_stall, FPU_ID_EX_stall,
    input CPU_ID_EX_flush, FPU_ID_EX_flush,
    input ID_PCSrc, EX_PCSrc, EX_is_JALR,

    input CPU_PCWrite, FPU_PCWrite,

    output IF_ID_stall, ID_EX_stall,
    output ID_EX_flush,

    output PCWrite
);

    assign IF_ID_stall = CPU_IF_ID_stall | FPU_IF_ID_stall;
    assign ID_EX_stall = CPU_ID_EX_stall | FPU_ID_EX_stall;
    assign ID_EX_flush = CPU_ID_EX_flush | FPU_ID_EX_flush;
    assign PCWrite = (EX_PCSrc || EX_is_JALR || ID_PCSrc) ? 1'b1 : (CPU_PCWrite & FPU_PCWrite);
endmodule