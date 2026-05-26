module PC_Target #(parameter W=32)(
    input [W-1:0]pc,
    input [W-1:0]imm,
    output Target
);
    assign Target = pc + imm;
endmodule