module FPU_Hazard (
    input clk, reset,
    input ID_is_FPU, EX_is_FPU, ID_is_FSW, EX_is_FLW,
    input [4:0]EX_Rd, ID_Rs1, ID_Rs2,
    output FPU_Valid, Rs1, Rs2,
    output reg IF_ID_stall, ID_EX_stall,
    output reg ID_EX_flush,
    output reg PCWrite
);
    wire [2:0]FPU_Left;

    FPU_Check u_FPU_Check(
        .clk(clk), .reset(reset),
        .ID_is_FPU(ID_is_FPU), .EX_is_FPU(EX_is_FPU), .ID_is_FSW(ID_is_FSW),
        .ID_Rs1(ID_Rs1), .ID_Rs2(ID_Rs2),
        .EX_Rd(EX_Rd),
        .FPU_Valid(FPU_Valid), . FPU_6clk(FPU_6clk),
        .FPU_Left(FPU_Left),
        .Rs1(Rs1), .Rs2(Rs2)
    ); 

    always @(*) begin
        {IF_ID_stall, ID_EX_stall, PCWrite} = 3'b001;
        ID_EX_flush = 1'b0;
        if(FPU_6clk)begin
            IF_ID_stall = 1'b1;
            ID_EX_flush = 1'b1;
            PCWrite = 1'b0;
        end
        else begin
            case (1'b1)
                (FPU_Left != 3'b000): begin
                    IF_ID_stall = 1'b1;
                    ID_EX_flush = 1'b1;
                    PCWrite = 1'b0;
                end
                FPU_Valid :begin
                    IF_ID_stall = 1'b0;
                    ID_EX_stall = 1'b0;
                    PCWrite = 1'b1;
                end
                (EX_is_FLW && ID_is_FPU) :begin
                    if((EX_Rd == ID_Rs1) || (EX_Rd == ID_Rs2))begin
                        IF_ID_stall = 1'b1;
                        ID_EX_flush = 1'b1;
                        PCWrite = 1'b0;
                    end
                    else begin
                        IF_ID_stall = 1'b0;
                        ID_EX_stall = 1'b0;
                        PCWrite = 1'b1;
                    end
                end
                default: {IF_ID_stall, ID_EX_stall, PCWrite} = 3'b001;
            endcase
        end
    end
  
endmodule