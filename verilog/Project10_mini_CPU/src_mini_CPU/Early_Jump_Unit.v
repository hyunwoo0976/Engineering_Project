module Early_Jump_Unit #(parameter W=32)(
    input [W-1:0] Imm,
    input [W-1:0] pc,
    input [W-1:0] Rs1_data,
    input is_JAL, is_JALR,
    output reg [W-1:0] Early_Target,
    output reg PCSrc
);
    wire [W-1:0] JAL_add = Imm + pc;
    wire [W-1:0] JALR_add = (Rs1_data + Imm) & ~32'b1;


    always @(*) begin
        PCSrc = 1'b0;
        Early_Target = 32'b0;
        if(is_JAL) begin
            Early_Target = JAL_add;
            PCSrc = 1'b1;
        end
        else if(is_JALR) begin
            Early_Target = JALR_add;
            PCSrc = 1'b1;
        end
        else begin
            Early_Target = pc;
            PCSrc = 1'b0;
        end
    end


endmodule