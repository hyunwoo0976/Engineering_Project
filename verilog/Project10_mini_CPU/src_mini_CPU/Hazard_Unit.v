module Hazard_Unit (
    input ID_PCSrc, EX_PCSrc,
    input EX_MemRead, ID_RegWrite,
    input EX_is_JALR,
    input [4:0]EX_Rd, ID_Rs1,ID_Rs2,
    output reg IF_ID_flush,
    output reg ID_EX_flush,
    output reg PCWrite,
    output reg IF_ID_stall,
    output reg ID_EX_stall
);

    always @(*)begin
        IF_ID_flush = 1'b0;
        ID_EX_flush = 1'b0;
        IF_ID_stall = 1'b0;
        ID_EX_stall = 1'b0;
        PCWrite = 1'b1;
        if(ID_PCSrc)begin                   //JAL, Early Jump
            IF_ID_flush = 1'b1;
        end
        else if(EX_PCSrc)begin              //branch
            IF_ID_flush = 1'b1;
            ID_EX_flush = 1'b1;
        end
        else if(EX_is_JALR)begin            //JALR
            IF_ID_flush = 1'b1;
            ID_EX_flush = 1'b1;
        end
        else if((EX_MemRead &&  ID_RegWrite) && (EX_Rd !=5'b0) && ((EX_Rd == ID_Rs1) || (EX_Rd == ID_Rs2))) begin       //Load-USE(LW->JALR..)
            ID_EX_flush = 1'b1;
            IF_ID_stall = 1'b1;
            PCWrite = 1'b0;
        end
    end
endmodule