module CPU_Forwarding_Unit #(parameter W=32)(
    input  MEM_RegWrite, WB_RegWrite,
    input [4:0] MEM_Rd, WB_Rd,
    input [4:0] EX_Rs1, EX_Rs2,
    input EX_uses_Rs1, EX_uses_Rs2,
    output reg [1:0] MEMtoEX_forward,               //01: Rs1=Rs2 / 10: Rs1 / 11: Rs2 / default : 00
    output reg [1:0] WBtoEX_forward                 //01: Rs1=Rs2 / 10: Rs1 / 11: Rs2 / default : 00
); 
    wire MEM_Rd_nz = (MEM_Rd != 5'b0) ? 1'b1 : 1'b0;
    wire WB_Rd_nz = (WB_Rd != 5'b0) ? 1'b1 : 1'b0;

    wire MEMtoEX_fwd1 = (MEM_RegWrite && (MEM_Rd == EX_Rs1) && MEM_Rd_nz && EX_uses_Rs1);
    wire MEMtoEX_fwd2 = (MEM_RegWrite && (MEM_Rd == EX_Rs2) && MEM_Rd_nz && EX_uses_Rs2);
    wire MEMtoEX_both_fwd = MEMtoEX_fwd1 && MEMtoEX_fwd2;

    wire WBtoEX_fwd1 = (WB_RegWrite && (WB_Rd == EX_Rs1) && WB_Rd_nz && EX_uses_Rs1);
    wire WBtoEX_fwd2 = (WB_RegWrite && (WB_Rd == EX_Rs2) && WB_Rd_nz && EX_uses_Rs2);
    wire WBtoEX_both_fwd = WBtoEX_fwd1 && WBtoEX_fwd2;


    always @(*) begin
        {MEMtoEX_forward, WBtoEX_forward} = 4'b0000;
        if(MEMtoEX_both_fwd)begin
            MEMtoEX_forward = 2'b01;
        end
        else if(MEMtoEX_fwd1)begin
            MEMtoEX_forward = 2'b10;
        end
        else if(MEMtoEX_fwd2)begin
            MEMtoEX_forward = 2'b11;
        end

        if(!MEMtoEX_both_fwd && WBtoEX_both_fwd)begin
            WBtoEX_forward = 2'b01;
        end
        else if(!MEMtoEX_fwd1 && WBtoEX_fwd1)begin
            WBtoEX_forward = 2'b10;
        end
        else if(!MEMtoEX_fwd2 && WBtoEX_fwd2)begin
            WBtoEX_forward = 2'b11;
        end
    end
endmodule