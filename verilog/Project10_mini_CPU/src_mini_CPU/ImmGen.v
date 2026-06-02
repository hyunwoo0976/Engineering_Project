module ImmGen #(parameter W=32)(
    input [W-1:0]inst,
    output reg [W-1:0]imm_out
);
    wire [6:0]Opcode=inst[6:0];

    always @(*)begin
        imm_out=32'b0;
        
        case (Opcode)
            7'b0010011, 7'b0000011, 7'b1100111:begin
                imm_out = {{20{inst[31]}}, inst[31:20]};
            end
            7'b0100011: begin
                imm_out = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            end
            7'b1100011: begin
                imm_out = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            end
            7'b1101111: begin
                imm_out = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            end
            default: imm_out=32'b0;

        endcase
    end
endmodule
