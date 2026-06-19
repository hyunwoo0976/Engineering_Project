module Main_Decoder #(parameter W=32)(
    input [W-1:0]instruction,
    output reg RegWrite,    //save the value to the register file when finished?
    output reg MemWrite,    //write the value to RAM
    output reg MemRead,     //Read the value from RAM?
    output reg Branch,      //prepare to switch PC
    output reg ALUsrc,      //MUX : Rs2 or IMM as second value
    output reg MemtoReg,    //MUX : select ALU result or Memory data
    output reg FRegWrite,
    output funct7_bit30,//ALU_Control
    output [6:0]funct7,
    output [2:0]funct3,
    output [4:0]rs1,rs2,
    output [4:0]rd,
    output reg [1:0]ALUOp,
    output reg is_FPU,
    output reg is_LW,is_SW,
    output reg is_BEQ,is_BNE, is_BLT, is_BGE,
    output reg is_JAL, is_JALR
);
    wire [6:0]Funct7 = instruction[31:25];
    wire [4:0]Rs2 = instruction[24:20];
    wire [4:0]Rs1 = instruction[19:15];
    wire [2:0]Funct3 = instruction[14:12];
    wire [4:0]Rd = instruction[11:7];
    wire [6:0]Opcode = instruction[6:0];
    wire [4:0]Funct5 = instruction[31:27];

    wire is_R_type = (Opcode == 7'b0110011); //R-type
    wire is_Imm_alu = (Opcode == 7'b0010011); //I-type
    wire is_branch = (Opcode == 7'b1100011); //B-type
    wire is_load = (Opcode == 7'b0000011); //I-type, LW
    wire is_store = (Opcode == 7'b0100011); //S-type, SW

    assign funct7_bit30=instruction[30];
    assign funct7 = Funct7;
    assign funct3=Funct3;
    assign rs1=Rs1;
    assign rs2=Rs2;
    assign rd=Rd;



   
    always @(*)begin
        {is_LW, is_SW} = 2'b00;
        {is_BEQ, is_BNE, is_BLT, is_BGE} = 4'b0000;
        {is_JAL, is_JALR} = 2'b00;
        {RegWrite, MemWrite, MemRead, Branch, ALUsrc, MemtoReg, FRegWrite}=7'b0;
        is_FPU=1'b0;
        ALUOp=2'b00;
        case (Opcode)
            7'b0110011: begin       //R-type: ADD, SUB, OR, XOR...
                ALUOp=2'b10;
                RegWrite=1'b1;
                ALUsrc=1'b0;
            end
            7'b0010011: begin       //I-type: ANDI, ADDI...
                ALUOp=2'b11;
                RegWrite=1'b1;
                ALUsrc=1'b1;
            end
            7'b0000011: begin       //LW
                is_LW=1'b1;
                ALUOp=2'b00;
                MemRead=1'b1;
                MemtoReg=1'b1;
                RegWrite=1'b1;
                ALUsrc=1'b1;
            end
            7'b0100011:begin        //SW
                is_SW=1'b1;
                ALUOp=2'b00;
                MemWrite=1'b1;
                ALUsrc=1'b1;
            end
            7'b1100011: begin
                ALUOp=2'b01;
                Branch=1'b1;
                if(Funct3==3'b000)begin         //BEQ
                    is_BEQ=1'b1;
                end
                else if(Funct3==3'b001)begin    //BNE
                    is_BNE=1'b1;
                end
                else if(Funct3==3'b100)begin    //BLT
                    is_BLT=1'b1;
                end
                else if(Funct3==3'b101)begin    //BGE
                    is_BGE=1'b1;
                end
            end
            7'b1101111: begin                   //JAL
                is_JAL=1'b1;
                Branch=1'b1;
                RegWrite=1'b1;
                ALUOp=2'b00;
                ALUsrc=1'b1;
            end
            7'b1100111: begin                   //JALR
                is_JALR=1'b1;
                Branch=1'b1;
                RegWrite=1'b1;
                ALUsrc=1'b1;
                ALUOp=2'b00;
            end
            7'b1010011: begin
                if(Funct5 == 5'b10100) begin
                    RegWrite = 1'b1;
                    is_FPU = 1'b1;
                end
                else begin
                    FRegWrite = 1'b1;
                    is_FPU = 1'b1;
                end
            end

            default: ;
        endcase
    end
    
endmodule