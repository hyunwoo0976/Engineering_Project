module FPU_Control #(parameter W=32)(
    input [6:0]Funct7,
    input [2:0]Funct3,
    input is_FPU,
    output reg error,
    output [2:0]rm,
    output reg FPU_en,
    output reg [1:0]FPU_Control
);
    wire [4:0]funct5 = Funct7[6:2]; //ADD: 00000, SUB: 00001, MUL: 00100
    wire [1:0]fmt = Funct7[1:0];

    assign rm = Funct3;          //000(RNE) , 001(RTZ)



    always @(*) begin
        FPU_en = 1'b0;
        FPU_Control = 2'b00;
        error = 1'b0;
        if(is_FPU)begin
            if(fmt == 2'b00) begin
                FPU_en = 1'b1;
                case (funct5)
                    5'b00000: begin
                        FPU_Control = 2'b00;      //ADD
                    end
                    5'b00001: begin
                        FPU_Control = 2'b01;      //SUB
                    end
                    5'b00100: begin
                        FPU_Control = 2'b10;      //MUL
                    end
                    5'b10100: begin
                        FPU_Control = 2'b01;      //Branch
                    end
                    default : begin
                        FPU_en = 1'b0;
                        error = 1'b1;
                    end
                endcase
            end
            else begin
                FPU_en = 1'b0;
                error = 1'b1;
            end
        end
        else begin
            FPU_en = 1'b0;
            error = 1'b1;
        end
    end
endmodule