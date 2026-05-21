module Decoder #(parameter W=32)(
    input [W-1:0]instruction,
    output reg RegWrite,    //save the value to the register file when finished?
    output reg MemWrite,    //write the value to RAM
    output reg MemRead,     //Read the value from RAM?
    output reg Branch,      //prepare to switch PC
    output reg ALUsrc,      //MUX : Rs2 or IMM as second value
    output reg MemtoReg,    //MUX : select ALU result or Memory data
    output funct7_bit30,//ALU_Control
    output reg [1:0]ALUOp,
    output reg FPU_en
);
    wire [6:0]Funct7=instruction[31:25];
    wire [4:0]Rs2=instruction[24:20];
    wire [4:0]Rs1=instruction[19:15];
    wire [2:0]Funct3=instruction[14:12];
    wire [4:0]Rd=instruction[11:7];
    wire [6:0]Opcode=instruction[6:0];

    wire is_R_type = (Opcode == 7'b0110011); //R-type
    wire is_Imm_alu = (Opcode == 7'b0010011); //I-type
    wire is_branch = (Opcode == 7'b1100011); //B-type
    wire is_load = (Opcode == 7'b0000011); //I-type, LW
    wire is_store = (Opcode == 7'b0100011); //S-type, SW
    wire is_FPU= (Opcode == 7'b1010011);

    assign funct7_bit30=instruction[30];

    reg is_LW,is_SW;
    reg is_BEQ,is_BNE, is_BLT, is_BGE;
    reg is_JAL, is_JALR;


   
    always @(*)begin
        {is_LW, is_SW} = 2'b00;
        {is_BEQ, is_BNE, is_BLT, is_BGE} = 4'b0000;
        {is_JAL, is_JALR} = 2'b00;
        {RegWrite,MemWrite,MemRead,Branch,ALUsrc,MemtoReg}=6'b0;
        FPU_en=1'b0;
        ALUOp=2'b00;
        case (Opcode)
            7'b0110011: begin
                ALUOp=2'b10;
                RegWrite=1'b1;
                ALUsrc=1'b0;
            end
            7'b0010011: begin
                ALUOp=2'b10;
                RegWrite=1'b1;
                ALUsrc=1'b1;
            end
            7'b0000011: begin
                is_LW=1'b1;
                ALUOp=2'b00;
                MemRead=1'b1;
                MemtoReg=1'b1;
                RegWrite=1'b1;
                ALUsrc=1'b1;
            end
            7'b0100011:begin
                is_SW=1'b1;
                ALUOp=2'b00;
                MemWrite=1'b1;
                ALUsrc=1'b1;
            end
            7'b1100011: begin
                ALUOp=2'b01;
                Branch=1'b1;
                if(Funct3==3'b000)begin
                    is_BEQ=1'b1;
                end
                else if(Funct3==3'b001)begin
                    is_BNE=1'b1;
                end
                else if(Funct3==3'b100)begin
                    is_BLT=1'b1;
                end
                else if(Funct3==3'b101)begin
                    is_BGE=1'b1;
                end
            end
            7'b1101111: begin
                is_JAL=1'b1;
                Branch=1'b1;
                RegWrite=1'b1;
                ALUOp=2'b00;
                ALUsrc=1'b1;
            end
            7'b1100111: begin
                is_JALR=1'b1;
                Branch=1'b1;
                RegWrite=1'b1;
                ALUsrc=1'b1;
                ALUOp=2'b00;
            end
            7'b1010011: begin
                FPU_en=1'b1;
                RegWrite=1'b1;
                ALUOp=2'b10;
            end

            default: ;
        endcase
    end
    
endmodule