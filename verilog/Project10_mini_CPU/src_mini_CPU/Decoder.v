module Decoder #(parameter W=32)(
    input [W-1:0]order,
    output [5:0]Opcode,
    output [4:0]Rs1,
    output [4:0]Rs2,
    output [4:0]Rd,
    output [10:0]Funct,
    output [15:0]Imm,

    output FPU_en,
    output reg[1:0]op
);
    assign Opcode=order[W-1:26];
    assign Rs1=order[25:21];
    assign Rs2=order[20:16];
    assign Rd=order[15:11];
    assign Funct=order[10:0];
    assign Imm=order[15:0];
    
    wire is_FADD=(Opcode==6'b000000 && Funct==11'd1);//op=00
    wire is_FSUB=(Opcode==6'b000000 && Funct==11'd2);//op=01
    wire is_FMUL=(Opcode==6'b000000 && Funct==11'd2);//op=10
    assign FPU_en=(is_FADD | is_FMUL | is_FSUB)? 1'b1:1'b0;
    always @(*)begin
        if(is_FADD)begin
            op=2'b00;
        end
        else if(is_FSUB)begin
            op=2'b01;
        end
        else if(is_FMUL)begin
            op=2'b10;
        end
        else begin
            op=2'b00;
        end
    end
endmodule