module PC_MUX #(parameter W=32)(
    input [W-1:0] Target,
    input [W-1:0] Early_Target,
    input [W-1:0] JALR_Target,
    input [W-1:0] next_pc,
    input ID_PCSrc, EX_PCSrc,EX_is_JALR,
    output reg [W-1:0] final_next_pc
);

    always @(*) begin
        final_next_pc = next_pc;
        if(ID_PCSrc) begin
            final_next_pc = Early_Target;
        end
        else if(EX_PCSrc) begin
            final_next_pc = Target;
        end
        else if(EX_is_JALR) begin
            final_next_pc = JALR_Target;
        end
    end
        
endmodule