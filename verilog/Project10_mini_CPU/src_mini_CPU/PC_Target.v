module PC_Target #(parameter W=32)(
    input [W-1:0]pc,
    input [W-1:0]imm,
    output [W-1:0]Target
);
    assign Target = pc + imm;
endmodule