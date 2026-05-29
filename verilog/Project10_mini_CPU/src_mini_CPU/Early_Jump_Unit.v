module Early_Jump_Unit #(parameter W=32)(
    input [W-1:0] Imm,
    input [W-1:0]pc,
    input is_JAL, 
    output [W-1:0] Early_Target,
    output PCSrc
);
    wire [W-1:0] tmp_add = Imm + pc;

    assign Early_Target = (is_JAL) ? tmp_add : pc;
    assign PCSrc = (Early_Target) ? 1'b1 : 1'b0;

endmodule