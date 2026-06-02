`default_nettype none
module Pipeline_CPU #(parameter W=32)(
    input clk, reset,
    output [W-1:0]current_pc,
    output [W-1:0]current_inst,
    output [W-1:0]wb_data
);

    assign current_pc = IF_pc;
    assign current_inst = ID_instruction;
    assign wb_data = WB_OUT;

//------------------------------[wire]--------------------------------
    wire IF_ID_flush, ID_EX_flush;
//------------------[Stage1: Fetch(IF)]-------------------------------
    wire [31:0] IF_pc;
    wire [31:0] IF_next_pc;
    wire [31:0] IF_final_next_pc;
    wire [31:0] IF_instruction;
//------------------[Stage2: Decode(ID)]------------------------------
    wire [31:0] ID_pc;
    wire [31:0] ID_instruction;
    wire ID_RegWrite, ID_MemtoReg, ID_MemRead, ID_MemWrite, ID_Branch, ID_ALUsrc;
    wire ID_funct7_bit30;
    wire [2:0] ID_Funct3;
    wire [1:0] ID_ALUOp;
    wire [3:0] ID_ALU_Control;
    wire ID_is_BEQ, ID_is_BNE, ID_is_BLT, ID_is_BGE;
    wire ID_is_JAL, ID_is_JALR;
    wire [31:0] ID_A, ID_B;
    wire [31:0] ID_imm;
    wire [4:0] ID_Rs1, ID_Rs2, ID_Rd;
    wire ID_PCSrc;
    wire [31:0]ID_Early_Target;

//------------------[Stage3: Execute(EX)]-----------------------------
    wire [31:0] EX_pc;
    wire EX_RegWrite, EX_MemtoReg, EX_MemRead, EX_MemWrite, EX_ALUsrc;
    wire [3:0] EX_ALU_Control;
    wire EX_is_BEQ, EX_is_BNE, EX_is_BLT, EX_is_BGE;
    wire [31:0] EX_A, EX_B;
    wire [31:0] EX_ALU_in_b;
    wire [31:0] EX_imm;
    wire [4:0] EX_Rd;
    wire [31:0] EX_Target;
    wire [31:0] EX_Result;
    wire EX_PCsrc;
    wire EX_ZF, EX_sign;

//------------------[Stage4: Memory(MEM)]-----------------------------
    wire MEM_RegWrite, MEM_MemWrite, MEM_MemRead, MEM_MemtoReg;
    wire [31:0] MEM_Result;
    wire [31:0] MEM_B;
    wire [4:0] MEM_Rd;
    wire [31:0] MEM_read_data;
//------------------[Stage5: Write-Back(WB)]--------------------------
    wire WB_RegWrite, WB_MemtoReg;
    wire [31:0] WB_Result;
    wire [4:0] WB_Rd;
    wire [31:0] WB_OUT;
    wire [31:0] WB_read_data;


//---------------------------------------------------------------
    Hazard_Unit u_Hazard_Unit(
        .ID_PCSrc(ID_PCSrc),
        .EX_PCSrc(EX_PCsrc),
        .IF_ID_flush(IF_ID_flush),
        .ID_EX_flush(ID_EX_flush)
    );
//---------------------------------------------------------------
//------------------[Stage1: Fetch(IF)]--------------------------
    PC_MUX #(.W(W))u_PC_MUX(
        .Target(EX_Target),
        .Early_Target(ID_Early_Target),
        .next_pc(IF_next_pc),
        .ID_PCSrc(ID_PCSrc),
        .EX_PCSrc(EX_PCsrc),
        .final_next_pc(IF_final_next_pc)
    );
    PC_reg #(.W(W))u_PC_reg(
        .clk(clk),
        .reset(reset),
        .next_pc(IF_final_next_pc),
        .pc(IF_pc)
    );
    PC_Adder #(.W(W))u_PC_Adder(
        .current_pc(IF_pc),
        .next_pc(IF_next_pc)
    );
    Instruction_Memory #(.W(W))u_IMEM(
        .pc(IF_pc),
        .instruction(IF_instruction)
    );
//------------------[Stage2: Decode(ID)]--------------------------
    Pipe_reg_1clk_control #(.W(64)) u_IF_ID_reg(
        .clk(clk), .reset(reset), .stall(1'b0), .flush(IF_ID_flush),
        .D({IF_pc, IF_instruction}),
        .Q({ID_pc, ID_instruction})
    );

    Main_Decoder #(.W(W))u_decoder(
        .instruction(ID_instruction),

        .RegWrite(ID_RegWrite),
        .MemRead(ID_MemRead),
        .MemtoReg(ID_MemtoReg),
        .Branch(ID_Branch),
        .MemWrite(ID_MemWrite),
        .ALUsrc(ID_ALUsrc),

        .funct7_bit30(ID_funct7_bit30),
        .funct3(ID_Funct3),

        .rs1(ID_Rs1),
        .rs2(ID_Rs2),
        .rd(ID_Rd),
        .ALUOp(ID_ALUOp),
        .FPU_en(),
        .is_LW(),
        .is_SW(),
        .is_BEQ(ID_is_BEQ),
        .is_BGE(ID_is_BGE),
        .is_BLT(ID_is_BLT),
        .is_BNE(ID_is_BNE),
        .is_JAL(ID_is_JAL),
        .is_JALR(ID_is_JALR)
    );
    Register_file #(.W(W))u_Regfile(
        .clk(clk),
        .reset(reset),

        //[WB sign]
        .we(WB_RegWrite),
        .we_data(WB_OUT),
        .we_addr(WB_Rd),

        //[ID sign]
        .Rs1_addr(ID_Rs1),
        .Rs2_addr(ID_Rs2),
        .Rt_addr(ID_Rd),
        .Rs1_data(ID_A),
        .Rs2_data(ID_B),
        .Rt_data()
    );
    ImmGen #(.W(W)) u_ImmGen(
        .inst(ID_instruction),
        .imm_out(ID_imm)
    );
    ALU_Control #(.W(W))u_ALU_Control(
        .funct7_bit30(ID_funct7_bit30),
        .Funct3(ID_Funct3),
        .ALUOp(ID_ALUOp),
        .ALU_Control(ID_ALU_Control)
    );
    Early_Jump_Unit #(.W(W))u_Early_Jump_Unit(
        .Imm(ID_imm),
        .pc(ID_pc),
        .Rs1_data(ID_A),
        .is_JALR(ID_is_JALR),
        .is_JAL(ID_is_JAL),
        .Early_Target(ID_Early_Target),
        .PCSrc(ID_PCSrc)
    );
    
//------------------[Stage3: Execute(EX)]--------------------------
    Pipe_reg_1clk_control #(.W(146)) u_ID_EX_reg(
        .clk(clk), .reset(reset), .stall(1'b0), .flush(ID_EX_flush),
        .D({
            ID_pc,
            ID_RegWrite,
            ID_MemtoReg,
            ID_MemRead,
            ID_MemWrite,
            ID_ALUsrc,
            ID_ALU_Control,
            ID_is_BEQ,
            ID_is_BNE,
            ID_is_BLT,
            ID_is_BGE,
            ID_A,
            ID_B,
            ID_imm,
            ID_Rd
        }),
        .Q({
            EX_pc,
            EX_RegWrite,
            EX_MemtoReg,
            EX_MemRead,
            EX_MemWrite,
            EX_ALUsrc,
            EX_ALU_Control,
            EX_is_BEQ,
            EX_is_BNE,
            EX_is_BLT,
            EX_is_BGE,
            EX_A,
            EX_B,
            EX_imm,
            EX_Rd
        })
    );

    PC_Target #(.W(W))u_PC_Target(
        .pc(EX_pc),
        .imm(EX_imm),
        .Target(EX_Target)
    );
    ALUsrc_MUX #(.W(W))u_ALUsrc(
        .ALUsrc(EX_ALUsrc),
        .Imm(EX_imm),
        .B(EX_B),
        .ALU_in_b(EX_ALU_in_b)
    );
    ALU #(.W(W)) u_ALU(
        .A(EX_A),
        .B(EX_ALU_in_b),
        .ALU_Control(EX_ALU_Control),
        .Result(EX_Result),
        .ZF(EX_ZF),
        .sign(EX_sign)
    );
    PCSrc u_PCSrc(
        .ZF(EX_ZF),
        .is_BEQ(EX_is_BEQ),
        .is_BNE(EX_is_BNE),
        .is_BLT(EX_is_BLT),
        .is_BGE(EX_is_BGE),
        .PCSrc(EX_PCsrc)
    );
//------------------[Stage4: Memory(MEM)]--------------------------
     Pipe_reg_1clk_control #(.W(73)) u_EX_MEM_reg(
        .clk(clk), .reset(reset), .stall(1'b0), .flush(1'b0),
        .D({
            EX_RegWrite,
            EX_MemWrite,
            EX_MemRead,
            EX_MemtoReg,
            EX_Result,
            EX_B,
            EX_Rd
        }),
        .Q({
            MEM_RegWrite,
            MEM_MemWrite,
            MEM_MemRead,
            MEM_MemtoReg,
            MEM_Result,
            MEM_B,
            MEM_Rd
        })
    );

    Data_Memory #(.W(W))u_Data_Memory(
        .clk(clk),
        .reset(reset),
        .MemWrite(MEM_MemWrite),
        .MemRead(MEM_MemRead),
        .addr(MEM_Result),
        .write_data(MEM_B),
        .read_data(MEM_read_data)
    );
//------------------[Stage5: Write-Back(WB)]--------------------------
    Pipe_reg_1clk_control #(.W(71)) u_MEM_WB_reg(
        .clk(clk), .reset(reset), .stall(1'b0), .flush(1'b0),
        .D({
            MEM_RegWrite,
            MEM_MemtoReg,
            MEM_read_data,
            MEM_Result,
            MEM_Rd
        }),
        .Q({
            WB_RegWrite,
            WB_MemtoReg,
            WB_read_data,
            WB_Result,
            WB_Rd
        })
    );
    CPU_MUX #(.W(W))u_CPU_MUX(
        .ALU_result(WB_Result),
        .mem_read_data(WB_read_data),
        .MemtoReg(WB_MemtoReg),
        .OUT(WB_OUT)
    );
    
endmodule
`default_nettype wire