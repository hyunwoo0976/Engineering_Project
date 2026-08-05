`default_nettype none
module Pipeline_CPU #(parameter W=32)(
    input clk, reset,
    output [W-1:0]current_pc,
    output [W-1:0]current_inst,
    output [W-1:0]wb_data,
    output wb_FPU_OF, wb_FPU_UF,
    output [4:0]wb_rd,
    output wb_regwrite, wb_fregwrite
);

    assign current_pc = IF_pc;
    assign current_inst = IF_instruction;
    assign wb_data = WB_OUT;
    assign wb_FPU_OF = WB_FPU_OF;
    assign wb_FPU_UF = WB_FPU_UF;
    assign wb_regwrite = WB_RegWrite;
    assign wb_fregwrite = WB_FRegWrite;
    assign wb_rd = WB_Rd;

//------------------------------[wire]--------------------------------
    wire IF_ID_flush, ID_EX_flush;
    wire IF_ID_stall, ID_EX_stall;
    wire PCWrite;
    wire [1:0]MEMtoEX_forward, WBtoEX_forward;
//------------------[Stage1: Fetch(IF)]-------------------------------
    wire [31:0] IF_pc;
    wire [31:0] IF_next_pc;
    wire [31:0] IF_final_next_pc;
    wire [31:0] IF_instruction;
//------------------[Stage2: Decode(ID)]------------------------------
    wire [31:0] ID_pc;
    wire [2:0] ID_rm;
    wire [31:0] ID_instruction;
    wire ID_RegWrite, ID_MemtoReg, ID_MemRead, ID_MemWrite, ID_Branch, ID_ALUsrc;
    wire ID_FRegWrite;
    wire ID_funct7_bit30;
    wire [2:0] ID_funct3;
    wire [6:0] ID_funct7;
    wire [1:0] ID_ALUOp;
    wire [3:0] ID_ALU_Control;
    wire [1:0] ID_FPU_Control;
    wire ID_is_BEQ, ID_is_BNE, ID_is_BLT, ID_is_BGE;
    wire ID_is_JAL, ID_is_JALR;
    wire ID_is_LW, ID_is_SW;
    wire ID_is_FPU, ID_is_FLW, ID_is_FSW;
    wire [31:0] ID_A, ID_B, ID_F_A, ID_F_B;
    wire [31:0] ID_imm;
    wire [4:0] ID_Rs1, ID_Rs2, ID_Rd;
    wire ID_PCSrc;
    wire [31:0]ID_Early_Target;
    wire ID_uses_Rs1, ID_uses_Rs2;
    wire ID_uses_FRs1, ID_uses_FRs2;
//------------------[Stage3: Execute(EX)]-----------------------------
    wire [31:0] EX_pc;
    wire [2:0] EX_rm;
    wire EX_RegWrite, EX_MemtoReg, EX_MemRead, EX_MemWrite, EX_ALUsrc;
    wire EX_FRegWrite;
    wire [3:0] EX_ALU_Control;
    wire [1:0] EX_FPU_Control;
    wire EX_is_BEQ, EX_is_BNE, EX_is_BLT, EX_is_BGE;
    wire EX_is_JALR, EX_is_SW;
    wire [31:0] EX_A, EX_B, EX_F_A, EX_F_B;
    wire [31:0] EX_in_A, EX_in_B;
    wire [31:0] EX_imm;
    wire [W-1:0] EX_read_data_B;
    wire [4:0] EX_Rs1, EX_Rs2;
    wire [4:0] EX_Rd;
    wire [31:0] EX_Target;
    wire [31:0] EX_ALU_Result, EX_FPU_Result;
    wire EX_PCsrc;
    wire EX_ALU_ZF, EX_ALU_sign;
    wire EX_FPU_ZF, EX_FPU_sign;
    wire EX_FPU_OF, EX_FPU_UF;
    wire EX_FPU_Valid;
    wire EX_is_FPU, EX_is_FLW, EX_is_FSW;
    wire [31:0] EX_JALR_Target;
    wire EX_uses_Rs1, EX_uses_Rs2;
    wire EX_uses_FRs1, EX_uses_FRs2;

    wire [31:0]EX_fin_pc;
    wire EX_fin_RegWrite, EX_fin_MemWrite, EX_fin_MemRead, EX_fin_MemtoReg, EX_fin_FRegWrite;
    wire [31:0]EX_fin_ALU_Result, EX_fin_FPU_Result;
    wire [4:0]EX_fin_Rd;
    wire EX_fin_FPU_OF, EX_fin_FPU_UF;
    wire EX_fin_uses_Rs1, EX_fin_uses_Rs2;
    wire [W-1:0]EX_fin_read_data_B;

    wire [W-1:0] EX_Result;

//------------------[Stage4: Memory(MEM)]-----------------------------
    wire [31:0] MEM_pc;
    wire MEM_RegWrite, MEM_MemWrite, MEM_MemRead, MEM_MemtoReg;
    wire MEM_FRegWrite;
    wire [31:0] MEM_read_data_B;
    wire [4:0] MEM_Rd;
    wire [31:0] MEM_read_data;
    wire MEM_FPU_OF, MEM_FPU_UF;
    
    wire [W-1:0] MEM_Result;

//------------------[Stage5: Write-Back(WB)]--------------------------
    wire [31:0] WB_pc;
    wire WB_RegWrite, WB_MemtoReg;
    wire WB_FRegWrite;
    wire [4:0] WB_Rd;
    wire [31:0] WB_OUT;
    wire [31:0] WB_read_data;
    wire WB_FPU_OF, WB_FPU_UF;

    wire [W-1:0] WB_Result;


//---------------------------------------------------------------
    Hazard_Unit u_Hazard_Unit(
        .clk(clk), .reset(reset),

        .ID_PCSrc(ID_PCSrc),
        .EX_PCSrc(EX_PCsrc),
        .EX_is_JALR(EX_is_JALR),

        .EX_MemRead(EX_MemRead), 
        .ID_RegWrite(ID_RegWrite),

        //[FPU]
        .ID_is_FPU(ID_is_FPU),
        .ID_is_FSW(ID_is_FSW),
        .EX_is_FPU(EX_is_FPU),
        .EX_is_FLW(EX_is_FLW),
        .FPU_Valid(EX_FPU_Valid),
        .Rs1(), .Rs2(),

        //[Addr]
        .EX_Rd(EX_Rd),
        .ID_Rs1(ID_Rs1),
        .ID_Rs2(ID_Rs2),

        //[flush & stall]
        .IF_ID_flush(IF_ID_flush),
        .ID_EX_flush(ID_EX_flush),
        .IF_ID_stall(IF_ID_stall),
        .ID_EX_stall(ID_EX_stall),
        .PCWrite(PCWrite)
    );
    Forwarding_Unit #(.W(W))u_Forwarding_Unit(
        .MEM_FRegWrite(MEM_FRegWrite), .WB_FRegWrite(WB_FRegWrite),
        .EX_is_FPU(EX_is_FPU), .EX_is_FLW(EX_is_FLW), .EX_is_FSW(EX_is_FSW),
        .EX_uses_Rs1(EX_uses_Rs1), .EX_uses_Rs2(EX_uses_Rs2),
        .EX_uses_FRs1(EX_uses_FRs1), .EX_uses_FRs2(EX_uses_FRs2), 

        .MEM_RegWrite(MEM_RegWrite),
        .WB_RegWrite(WB_RegWrite),

        //[Addr]
        .MEM_Rd(MEM_Rd),
        .WB_Rd(WB_Rd),
        .EX_Rs1(EX_Rs1),
        .EX_Rs2(EX_Rs2),

        //[Forward]
        .MEMtoEX_forward(MEMtoEX_forward),
        .WBtoEX_forward(WBtoEX_forward)
    );
//---------------------------------------------------------------
//------------------[Stage1: Fetch(IF)]--------------------------
    PC_MUX #(.W(W))u_PC_MUX(
        .JALR_Target(EX_JALR_Target),
        .Target(EX_Target),
        .Early_Target(ID_Early_Target),
        .next_pc(IF_next_pc),
        .ID_PCSrc(ID_PCSrc),
        .EX_PCSrc(EX_PCsrc),
        .EX_is_JALR(EX_is_JALR),
        .final_next_pc(IF_final_next_pc)
    );
    PC_reg #(.W(W))u_PC_reg(
        .clk(clk),
        .reset(reset),
        .PCWrite(PCWrite),
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
        .clk(clk), .reset(reset), .stall(IF_ID_stall), .flush(IF_ID_flush),
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

        .FRegWrite(ID_FRegWrite),

        .funct7_bit30(ID_funct7_bit30),
        .funct7(ID_funct7),
        .funct3(ID_funct3),

        .rs1(ID_Rs1),
        .rs2(ID_Rs2),
        .rd(ID_Rd),
        .ALUOp(ID_ALUOp),
        .is_FPU(ID_is_FPU),
        .is_FLW(ID_is_FLW),
        .is_FSW(ID_is_FSW),
        .is_LW(),
        .is_SW(ID_is_SW),
        .is_BEQ(ID_is_BEQ),
        .is_BGE(ID_is_BGE),
        .is_BLT(ID_is_BLT),
        .is_BNE(ID_is_BNE),
        .is_JAL(ID_is_JAL),
        .is_JALR(ID_is_JALR),
        .uses_Rs1(ID_uses_Rs1), .uses_Rs2(ID_uses_Rs2),
        .uses_FRs1(ID_uses_FRs1), .uses_FRs2(ID_uses_FRs2)
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
    Register_file #(.W(W))u_FPU_Regfile(
        .clk(clk),
        .reset(reset),

        //[WB sign]
        .we(WB_FRegWrite),
        .we_data(WB_OUT),
        .we_addr(WB_Rd),

        //[ID sign]
        .Rs1_addr(ID_Rs1),
        .Rs2_addr(ID_Rs2),
        .Rt_addr(ID_Rd), 
        .Rs1_data(ID_F_A),
        .Rs2_data(ID_F_B),
        .Rt_data()
    );
    ImmGen #(.W(W)) u_ImmGen(
        .inst(ID_instruction),
        .imm_out(ID_imm)
    );
    ALU_Control #(.W(W))u_ALU_Control(
        .funct7_bit30(ID_funct7_bit30),
        .Funct3(ID_funct3),
        .ALUOp(ID_ALUOp),
        .ALU_Control(ID_ALU_Control)
    );
    FPU_Control #(.W(W)) u_FPU_Control(
        .Funct7(ID_funct7),
        .Funct3(ID_funct3),
        .is_FPU(ID_is_FPU),
        .error(),
        .rm(ID_rm),
        .FPU_Control(ID_FPU_Control)
    );
    Early_Jump_Unit #(.W(W))u_Early_Jump_Unit(      //JAL일때 점프타겟 주소게산
        .Imm(ID_imm),
        .pc(ID_pc),
        .is_JAL(ID_is_JAL),
        .Early_Target(ID_Early_Target),
        .PCSrc(ID_PCSrc)
    );
    
//------------------[Stage3: Execute(EX)]--------------------------
    Pipe_reg_1clk_control #(.W(235)) u_ID_EX_reg(
        .clk(clk), .reset(reset), .stall(ID_EX_stall), .flush(ID_EX_flush),
        .D({
            ID_pc,
            ID_rm,
            ID_RegWrite,
            ID_MemtoReg,
            ID_MemRead,
            ID_MemWrite,
            ID_ALUsrc,
            ID_FRegWrite,
            ID_ALU_Control,
            ID_is_BEQ,
            ID_is_BNE,
            ID_is_BLT,
            ID_is_BGE,
            ID_is_SW,
            ID_is_JALR,
            ID_is_FPU,
            ID_is_FLW,
            ID_is_FSW,
            ID_A,
            ID_B,
            ID_F_A,
            ID_F_B,
            ID_imm,
            ID_Rs1,
            ID_Rs2,
            ID_Rd,
            ID_FPU_Control,
            ID_uses_Rs1,
            ID_uses_Rs2,
            ID_uses_FRs1,
            ID_uses_FRs2
        }),
        .Q({
            EX_pc,
            EX_rm,
            EX_RegWrite,
            EX_MemtoReg,
            EX_MemRead,
            EX_MemWrite,
            EX_ALUsrc,
            EX_FRegWrite,
            EX_ALU_Control,
            EX_is_BEQ,
            EX_is_BNE,
            EX_is_BLT,
            EX_is_BGE,
            EX_is_SW,
            EX_is_JALR,
            EX_is_FPU,
            EX_is_FLW,
            EX_is_FSW,      
            EX_A,
            EX_B,
            EX_F_A,
            EX_F_B,
            EX_imm,
            EX_Rs1,
            EX_Rs2,
            EX_Rd,
            EX_FPU_Control,
            EX_uses_Rs1,
            EX_uses_Rs2,
            EX_uses_FRs1,
            EX_uses_FRs2
        })
    );
    PC_Target #(.W(W))u_PC_Target(
        .pc(EX_pc),
        .imm(EX_imm),
        .Target(EX_Target)
    );
    port_MUX #(.W(W))u_port_MUX(
        .MEMtoEX_forward(MEMtoEX_forward), .WBtoEX_forward(WBtoEX_forward),
        .MEM_value(MEM_Result), .WB_value(WB_OUT),
        .imm(EX_imm),
        .ALUsrc(EX_ALUsrc), .EX_is_FPU(EX_is_FPU), .EX_is_FSW(EX_is_FSW), .EX_is_SW(EX_is_SW),
        .EX_A(EX_A), .EX_B(EX_B),
        .EX_F_A(EX_F_A), .EX_F_B(EX_F_B),
        .EX_is_JALR(EX_is_JALR),
        .EX_in_A(EX_in_A), .EX_in_B(EX_in_B),
        .EX_read_data_B(EX_read_data_B)
    );
   
    ALU #(.W(W)) u_ALU(
        .A(EX_in_A),
        .B(EX_in_B),
        .ALU_Control(EX_ALU_Control),
        .Result(EX_ALU_Result),
        .ZF(EX_ALU_ZF),
        .sign(EX_ALU_sign)
    );
    FPU #(.W(W)) u_FPU(
        .clk(clk), .reset(reset),
        .IN_A(EX_in_A),
        .IN_B(EX_in_B),
        .op(EX_FPU_Control),
        .FPU_en(EX_is_FPU),
        .rm(EX_rm),
        .ZF(EX_FPU_ZF),
        .sign(EX_FPU_sign),
        .OF(EX_FPU_OF),
        .UF(EX_FPU_UF),
        .error(),
        .result_out(EX_FPU_Result)
    );
    FPU_MUX #(.W(W)) u_FPU_MUX(
        .FPU_Valid(EX_FPU_Valid),
        .FPU_Result(EX_FPU_Result),
        .EX_FPU_Result(EX_fin_FPU_Result)
    );
    PCSrc u_PCSrc(
        .ZF(EX_ALU_ZF),
        .sign(EX_ALU_sign),
        .is_BEQ(EX_is_BEQ),
        .is_BNE(EX_is_BNE),
        .is_BLT(EX_is_BLT),
        .is_BGE(EX_is_BGE),
        .PCSrc(EX_PCsrc)
    );
    JALR_Jump_Unit #(.W(W)) u_JALR_Jump_Unit(
        .Imm(EX_imm),
        .Rs1_data(EX_in_A),
        .JALR_Target(EX_JALR_Target)
    );
    FPU_shadow_reg #(.W(108)) u_FPU_shadow_reg(
        .clk(clk), .reset(reset),
        .EX_is_FPU(EX_is_FPU),
        .FPU_Valid(EX_FPU_Valid),
        .D({
            EX_pc,
            EX_RegWrite,
            EX_MemWrite,
            EX_MemRead,
            EX_MemtoReg,
            EX_FRegWrite,
            EX_ALU_Result,
            EX_read_data_B,
            EX_Rd,
            EX_FPU_OF,
            EX_FPU_UF
        }),
        .Q({
            EX_fin_pc,
            EX_fin_RegWrite,
            EX_fin_MemWrite,
            EX_fin_MemRead,
            EX_fin_MemtoReg,
            EX_fin_FRegWrite,
            EX_fin_ALU_Result,
            EX_fin_read_data_B,
            EX_fin_Rd,
            EX_fin_FPU_OF,
            EX_fin_FPU_UF
        })
    );
    Result_MUX #(.W(W)) u_Result_MUX(
        .ALU_Result(EX_fin_ALU_Result),
        .FPU_Result(EX_fin_FPU_Result),
        .FPU_Valid(EX_FPU_Valid),
        .Result(EX_Result)
    );
//------------------[Stage4: Memory(MEM)]--------------------------
     Pipe_reg_1clk_control #(.W(108)) u_EX_MEM_reg(
        .clk(clk), .reset(reset), .stall(1'b0), .flush(1'b0),
        .D({
            EX_fin_pc,
            EX_fin_RegWrite,
            EX_fin_MemWrite,
            EX_fin_MemRead,
            EX_fin_MemtoReg,
            EX_fin_FRegWrite,
            EX_Result,
            EX_fin_read_data_B,
            EX_fin_Rd,
            EX_fin_FPU_OF,
            EX_fin_FPU_UF
        }),
        .Q({
            MEM_pc,
            MEM_RegWrite,
            MEM_MemWrite,
            MEM_MemRead,
            MEM_MemtoReg,
            MEM_FRegWrite,
            MEM_Result,
            MEM_read_data_B,
            MEM_Rd,
            MEM_FPU_OF,
            MEM_FPU_UF
        })
    );

    Data_Memory #(.W(W))u_Data_Memory(
        .clk(clk),
        .MemWrite(MEM_MemWrite),
        .MemRead(MEM_MemRead),
        .addr(MEM_Result),
        .write_data(MEM_read_data_B),
        .read_data(MEM_read_data)
    );
//------------------[Stage5: Write-Back(WB)]--------------------------
    Pipe_reg_1clk_control #(.W(106)) u_MEM_WB_reg(
        .clk(clk), .reset(reset), .stall(1'b0), .flush(1'b0),
        .D({
            MEM_pc,
            MEM_RegWrite,
            MEM_MemtoReg,
            MEM_FRegWrite,
            MEM_read_data,
            MEM_Result,
            MEM_Rd,
            MEM_FPU_OF, 
            MEM_FPU_UF
        }),
        .Q({
            WB_pc,
            WB_RegWrite,
            WB_MemtoReg,
            WB_FRegWrite,
            WB_read_data,
            WB_Result,
            WB_Rd,
            WB_FPU_OF, 
            WB_FPU_UF
        })
    );
    CPU_MUX #(.W(W))u_CPU_MUX(
        .Result(WB_Result),
        .mem_read_data(WB_read_data),
        .MemtoReg(WB_MemtoReg),
        .OUT(WB_OUT)
    );
    
endmodule
`default_nettype wire