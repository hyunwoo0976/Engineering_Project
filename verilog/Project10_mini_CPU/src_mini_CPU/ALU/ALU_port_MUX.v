module ALU_port_MUX #(parameter W=32)(
    //[A]
    input [W-1:0] EX_A,
    input [W-1:0] pc,
    input is_JALR,

    //[B]
    input [W-1:0] EX_B,
    input [W-1:0] Imm,
    input ALUsrc,
    
    //[forward]
    input [1:0] MEMtoEX_forward,                //01: Rs1=Rs2 / 10: Rs1 / 11: Rs2 / default : 00
    input [W-1:0] MEM_value,
    input [1:0] WBtoEX_forward,
    input [W-1:0] WB_value,

    output reg [W-1:0] EX_ALU_in_A, EX_ALU_in_B
);

    always @(*)begin
        if((MEMtoEX_forward == 2'b00) && (WBtoEX_forward == 2'b00))begin
            if(is_JALR)begin
                EX_ALU_in_A = pc;
                EX_ALU_in_B = 32'd4;
            end
            else begin
                EX_ALU_in_A = EX_A;
                EX_ALU_in_B = (ALUsrc) ? Imm : EX_B;
            end
        end
        else begin
            EX_ALU_in_A = EX_A;
            EX_ALU_in_B = EX_B;
            if(MEMtoEX_forward == 2'b01)begin
                EX_ALU_in_A = MEM_value;
                EX_ALU_in_B = MEM_value;
            end
            else if(MEMtoEX_forward == 2'b10)begin
                EX_ALU_in_A = MEM_value;
            end
            else if(MEMtoEX_forward == 2'b11)begin
                EX_ALU_in_A = MEM_value; 
            end
            else if(WBtoEX_forward == 2'b01)begin
                EX_ALU_in_A = WB_value;
                EX_ALU_in_B = WB_value;
            end
            else if(WBtoEX_forward == 2'b10)begin
                EX_ALU_in_A = WB_value;
            end
            else if(WBtoEX_forward == 2'b11)begin
                EX_ALU_in_B = WB_value; 
            end
        end
    end
endmodule