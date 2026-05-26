module PC_MUX #(parameter W=32)(
    input [W-1:0]Target,
    input [W-1:0]next_pc,
    input PCSrc,
    output [W-1:0]final_next_pc
);
    assign final_next_pc = (PCSrc) ? Target : next_pc;
endmodule