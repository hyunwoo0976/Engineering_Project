module JALR_Jump_Unit #(parameter W=32)(
    input [W-1:0] Imm,
    input [W-1:0] Rs1_data,
    output [W-1:0]JALR_Target
);
    wire [W-1:0] JALR_add = (Rs1_data + Imm) & ~32'b1;

    assign JALR_Target = JALR_add;

endmodule