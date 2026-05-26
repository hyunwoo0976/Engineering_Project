module Top_CPU #(parameter W=32)(
    input clk, reset,
    output [W-1:0]current_pc,
    output [W-1:0]current_inst,
    output [W-1:0]wb_data
);

    assign current_pc = pc;
    assign current_inst = instruction;
    assign wb_data = OUT;

//------------------------------[wire]--------------------------------
    wire [31:0]next_pc, pc;
    wire [31:0]instruction;
    wire RegWrite, MemRead, MemtoReg, MemWrite,Branch, ALUsrc;
    wire funct7_bit30;
    wire [2:0]Funct3;
    wire [4:0]Rs1,Rs2,Rd;
    wire [1:0]ALUOp;
    wire [31:0]OUT;
    wire [31:0]A,B;
    wire [31:0]imm;
    wire [3:0]ALU_Control;
    wire [31:0]ALU_in_b;
    wire [31:0]Result;
    wire [31:0]read_data;
    wire [31:0]Target;
    wire PCSrc;
    wire [31:0]final_next_pc;
    wire is_BEQ;
    wire ZF, sign;
//------------------[Stage1: Fetch(IF)]-------------------------------
//------------------[Stage2: Decode(ID)]------------------------------
//------------------[Stage3: Execute(EX)]-----------------------------
//------------------[Stage4: Memory(MEM)]-----------------------------
//------------------[Stage5: Write-Back(WB)]--------------------------




//---------------------------------------------------------------
//------------------[Stage1: Fetch(IF)]--------------------------
    PC_MUX #(.W(W))u_PC_MUX(
        .Target(Target),
        .next_pc(next_pc),
        .PCSrc(PCSrc),
        .final_next_pc(final_next_pc)
    );
    PC_Target #(.W(W))u_PC_Target(
        .pc(pc),
        .imm(imm),
        .Target(Target)
    );
    PCSrc #(.W(W))u_PCSrc(
        .ZF(ZF),
        .is_BEQ(is_BEQ),
        .PCSrc(PCSrc)
    );
    PC_reg #(.W(W))u_PC_reg(
        .clk(clk),
        .reset(reset),
        .next_pc(final_next_pc),
        .pc(pc)
    );
    PC_Adder #(.W(W))u_PC_Adder(
        .current_pc(pc),
        .next_pc(next_pc)
    );
    Instruction_Memory #(.W(W))u_IMEM(
        .pc(pc),
        .instruction(instruction)
    );
//------------------[Stage2: Decode(ID)]--------------------------

    Main_Decoder #(.W(W))u_decoder(
        .instruction(instruction),
        .RegWrite(RegWrite),
        .MemRead(MemRead),
        .MemtoReg(MemtoReg),
        .Branch(Branch),
        .MemWrite(MemWrite),
        .ALUsrc(ALUsrc),
        .funct7_bit30(funct7_bit30),
        .funct3(Funct3),
        .rs1(Rs1),
        .rs2(Rs2),
        .rd(Rd),
        .ALUOp(ALUOp),
        .FPU_en(),
        .is_LW(),
        .is_SW(),
        .is_BEQ(is_BEQ),
        .is_BGE(),
        .is_BLT(),
        .is_BNE(),
        .is_JAL(),
        .is_JALR()
    );
    Register_file #(.W(W))u_Regfile(
        .clk(clk),
        .reset(reset),
        .we(RegWrite),
        .we_data(OUT),
        .we_addr(Rd),
        .Rs1_addr(Rs1),
        .Rs2_addr(Rs2),
        .Rt_addr(Rd),
        .Rs1_data(A),
        .Rs2_data(B),
        .Rt_data()
    );
    ImmGen #(.W(W)) u_ImmGen(
        .inst(instruction),
        .imm_out(imm)
    );
    ALU_Control #(.W(W))u_ALU_Control(
        .funct7_bit30(funct7_bit30),
        .Funct3(Funct3),
        .ALUOp(ALUOp),
        .ALU_Control(ALU_Control)
    );
    ALUsrc #(.W(W))u_ALUsrc(
        .ALUsrc(ALUsrc),
        .Imm(imm),
        .B(B),
        .ALU_in_b(ALU_in_b)
    );
//------------------[Stage3: Execute(EX)]--------------------------
    ALU #(.W(W)) u_ALU(
        .A(A),
        .B(ALU_in_b),
        .ALU_Control(ALU_Control),
        .Result(Result),
        .ZF(ZF),
        .sign(sign)
    );
//------------------[Stage4: Memory(MEM)]--------------------------
    Data_Memory #(.W(W))u_Data_Memory(
        .clk(clk),
        .reset(reset),
        .MemWrite(MemWrite),
        .MemRead(MemRead),
        .addr(Result),
        .write_data(B),
        .read_data(read_data)
    );
//------------------[Stage5: Write-Back(WB)]--------------------------
    CPU_MUX #(.W(W))u_CPU_MUX(
        .ALU_result(Result),
        .mem_read_data(read_data),
        .MemtoReg(MemtoReg),
        .OUT(OUT)
    );
    
endmodule