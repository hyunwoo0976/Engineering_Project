module ALU_Control #(parameter W=32)(
    input funct7_bit30,
    input [2:0]Funct3,
    input [1:0]ALUOp,
    output reg [3:0]ALU_Control
);

    always @(*) begin
        ALU_Control=4'b0000;
        case(ALUOp)
            2'b00:begin
                ALU_Control=4'b0010;        //ADD
            end
            2'b01:begin
                ALU_Control=4'b0110;        //SUB
            end
            2'b10:begin
                case(Funct3)
                    3'b000: begin
                        if(funct7_bit30)begin
                            ALU_Control = 4'b0110;                          //SUB
                        end
                        else begin
                            ALU_Control = 4'b0010;                          //ADD
                        end
                    end
                    3'b001: begin
                        ALU_Control=4'b1000;                                //SLL
                    end
                    3'b100:begin
                        ALU_Control=4'b0000;                                //XOR
                    end
                    3'b101:begin
                        if(funct7_bit30)begin
                            ALU_Control = 4'b1010;                          //SRA
                        end
                        else begin
                            ALU_Control = 4'b1001;                          //SRL
                        end
                    end
                    3'b110:begin
                        ALU_Control=4'b0001;                                //OR
                    end
                    3'b111:begin
                        ALU_Control=4'b0000;                                //AND
                    end
                endcase
            end
            2'b11: begin
                case(Funct3)
                    3'b000:begin                                            //ADDI
                        ALU_Control = 4'b0010;
                    end
                    3'b111:begin                                            //ANDI
                        ALU_Control = 4'b0110;
                    end
                endcase
            end
            default: ALU_Control=4'b0000;
        endcase
    end
endmodule