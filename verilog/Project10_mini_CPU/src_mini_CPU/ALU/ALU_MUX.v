module ALU_MUX #(parameter W=32)(
    input [W-1:0]logic_result,
    input [W-1:0]calculate_result,
    input [W-1:0]shift_result,
    input [3:0]ALU_Control,
    output reg [W-1:0]ALU_result
);

    always @(*)begin
        case(ALU_Control)
            4'b0000, 4'b0001, 4'b0011 : begin
                ALU_result = logic_result;
            end
            4'b0010, 4'b0110 : begin
                ALU_result = calculate_result;
            end
            4'b1000, 4'b1001, 4'b1010 : begin
                ALU_result = shift_result;
            end
            default: ALU_result = {W{1'b0}};
        endcase
    end
endmodule