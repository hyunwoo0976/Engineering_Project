module Forwarding_Unit #(parameter W=32)(
    input EX_RegWrite, MEM_RegWrite, WB_RegWrite, EX_MemRead, EX_MemWrite,
    input [4:0] EX_Rd, MEM_Rd, WB_Rd,
    input [4:0] ID_Rs1, ID_Rs2, EX_Rs1, EX_Rs2,
    output reg [1:0] MEMtoEX_forward,               //01: Rs1=Rs2 / 10: Rs1 / 11: Rs2 / default : 00
    output reg [1:0] WBtoEX_forward                 //01: Rs1=Rs2 / 10: Rs1 / 11: Rs2 / default : 00
); 
    wire EX_Rd_nz = (EX_Rd != 5'b0) ? 1'b1 : 1'b0;
    wire MEM_Rd_nz = (MEM_Rd != 5'b0) ? 1'b1 : 1'b0;
    wire WB_Rd_nz = (WB_Rd != 5'b0) ? 1'b1 : 1'b0;

    wire ID_EX_Rs1_Rs2 = ((EX_Rd == ID_Rs1) || (EX_Rd == ID_Rs2)) ? 1'b1 : 1'b0;
    wire EX_MEM_Rs1_Rs2 = ((MEM_Rd == EX_Rs1) || (MEM_Rd == EX_Rs2)) ? 1'b1 : 1'b0;
    wire EX_WB_Rs1_Rs2 = ((WB_Rd == EX_Rs1) || (WB_Rd == EX_Rs2)) ? 1'b1 : 1'b0;

    wire EX_MEM_Rs1 = (MEM_Rd == EX_Rs1) ? 1'b1 : 1'b0;

    always @(*)begin
        {MEMtoEX_forward, WBtoEX_forward} = 2'b00; 
        case(1'b1)
            (MEM_RegWrite && EX_MemRead && MEM_Rd_nz && EX_MEM_Rs1): begin          //R-type -> LW
                MEMtoEX_forward = 2'b10;
            end
            (MEM_RegWrite && !EX_MemWrite && MEM_Rd_nz && EX_MEM_Rs1_Rs2): begin     //R-type -> R-type
                if(EX_Rs1 == EX_Rs2)begin
                    MEMtoEX_forward = 2'b01;
                end
                else if(MEM_Rd == EX_Rs1)begin
                    MEMtoEX_forward = 2'b10;
                end
                else if(MEM_Rd == EX_Rs2)begin
                    MEMtoEX_forward = 2'b11;
                end
            end
            (WB_RegWrite && WB_Rd_nz && EX_WB_Rs1_Rs2): begin            //R-type-> ~ ->R-type
                if(EX_Rs1 == EX_Rs2)begin
                    WBtoEX_forward = 2'b01;
                end
                else if(WB_Rd == EX_Rs1)begin
                    WBtoEX_forward = 2'b10;
                end
                else if(WB_Rd == EX_Rs2)begin
                    WBtoEX_forward = 2'b11;
                end
            end
            (MEM_RegWrite && EX_MemWrite && MEM_Rd_nz && EX_MEM_Rs1_Rs2): begin     //R-type -> SW
                if(EX_Rs1 == EX_Rs2)begin
                    MEMtoEX_forward = 2'b01;
                end
                else if(MEM_Rd == EX_Rs1)begin
                    MEMtoEX_forward = 2'b10;
                end
                else if(MEM_Rd == EX_Rs2)begin
                    MEMtoEX_forward = 2'b11;
                end               
            end    
        endcase
    end
endmodule