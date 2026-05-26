module calculate_group #(parameter W=32)(
    input [W-1:0]A,
    input [W-1:0]B,
    input [3:0]ALU_Control,
    output [W-1:0]calculate_result,
    output ZF,sign
);
    reg [W:0]tmp_result;

    always @(*)begin
        case(ALU_Control)
            4'b0010: begin
                tmp_result={1'b0,A} + {1'b0,B};
            end
            4'b0110: begin
                tmp_result={1'b0,A} - {1'b0,B};
            end
            default: tmp_result={W+1{1'b0}};
        endcase
    end

    assign calculate_result=tmp_result[W-1:0];
    assign ZF = (calculate_result == {W{1'b0}}) ? 1'b1 : 1'b0;
    assign sign = calculate_result[W-1];
endmodule