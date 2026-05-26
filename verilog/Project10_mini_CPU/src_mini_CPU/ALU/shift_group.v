module shift_group #(parameter W=32)(
    input [W-1:0]A,
    input [W-1:0]B,
    input [3:0]ALU_Control,
    output reg [W-1:0]shift_result 
);

    wire [4:0]shift_amt= B[4:0];

    always @(*) begin
        case (ALU_Control)
            4'b1000: begin
                shift_result = A << shift_amt;
            end
            4'b1001: begin
                shift_result = A >> shift_amt;
            end
            4'b1010: begin
                shift_result = $signed (A) >>> shift_amt;
            end
            default: shift_result={W{1'b0}};
        endcase
    end
endmodule