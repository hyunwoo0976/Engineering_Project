module logical_group #(parameter W=32)(
    input [W-1:0]A,
    input [W-1:0]B,
    input [3:0]ALU_Control,
    output reg [W-1:0]logic_result
);
    always @(*) begin
        case (ALU_Control)
            4'b0000:begin
                logic_result = A & B;
            end
            4'b0001:begin
                logic_result= A | B;
            end
            4'b0011:begin
                logic_result= A ^ B;
            end
            default: logic_result={W{1'b0}};
        endcase
    end
endmodule