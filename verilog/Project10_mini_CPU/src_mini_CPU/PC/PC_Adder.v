module PC_Adder #(parameter W = 32)(
    input [W-1:0]current_pc,
    output [W-1:0]next_pc
);
    assign next_pc = current_pc + 32'd4;
endmodule