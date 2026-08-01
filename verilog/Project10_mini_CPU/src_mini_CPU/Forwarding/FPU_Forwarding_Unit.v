module FPU_Forwarding_Unit #(parameter W=32)(
    input  MEM_FRegWrite, WB_FRegWrite, MEM_RegWrite, WB_RegWrite,
    input [4:0] MEM_Rd, WB_Rd,
    input [4:0] EX_Rs1, EX_Rs2,
    input EX_uses_Rs1, EX_uses_Rs2, EX_uses_FRs1, EX_uses_FRs2,
    output reg [1:0] MEMtoEX_forward,               //01: Rs1=Rs2 / 10: Rs1 / 11: Rs2 / default : 00
    output reg [1:0] WBtoEX_forward                 //01: Rs1=Rs2 / 10: Rs1 / 11: Rs2 / default : 00
); 
    wire MEM_nz = (MEM_Rd != 5'b00000) ? 1'b1 : 1'b0;
    wire WB_nz = (WB_Rd != 5'b00000) ? 1'b1 : 1'b0;

    wire MEM_fwd_Rs1 = ((MEM_RegWrite && EX_uses_Rs1 && MEM_nz) || (MEM_FRegWrite && EX_uses_FRs1)) && (MEM_Rd == EX_Rs1);
    wire MEM_fwd_Rs2 = ((MEM_RegWrite && EX_uses_Rs2 && MEM_nz) || (MEM_FRegWrite && EX_uses_FRs2)) && (MEM_Rd == EX_Rs2);

    wire WB_fwd_Rs1 = ((WB_RegWrite && EX_uses_Rs1 && WB_nz) || (WB_FRegWrite && EX_uses_FRs1)) && (WB_Rd == EX_Rs1);
    wire WB_fwd_Rs2 = ((WB_RegWrite && EX_uses_Rs2 && WB_nz) || (WB_FRegWrite && EX_uses_FRs2)) && (WB_Rd == EX_Rs2);

    always @(*) begin
        {MEMtoEX_forward, WBtoEX_forward} = 4'b0000;
        if(MEM_fwd_Rs1 && MEM_fwd_Rs2)begin
            MEMtoEX_forward = 2'b01;
        end
        else if(MEM_fwd_Rs1)begin
            MEMtoEX_forward = 2'b10;
        end
        else if(MEM_fwd_Rs2)begin
            MEMtoEX_forward = 2'b11;
        end

        if(!MEM_fwd_Rs1 && !MEM_fwd_Rs2 && WB_fwd_Rs1 && WB_fwd_Rs2)begin
            WBtoEX_forward = 2'b01;
        end
        else if(!MEM_fwd_Rs1 && WB_fwd_Rs1)begin
            WBtoEX_forward = 2'b10;
        end
        else if(!MEM_fwd_Rs2 && WB_fwd_Rs2)begin
            WBtoEX_forward = 2'b11;
        end
    end


endmodule