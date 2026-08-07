module port_MUX #(parameter W=32)(
    input [1:0]MEMtoEX_forward, WBtoEX_forward,
    input [W-1:0]MEM_value, WB_value,
    input [W-1:0]imm,
    input [W-1:0]EX_pc,
    input ALUsrc, EX_is_FPU,
    input EX_is_SW, EX_is_FSW,
    input [W-1:0]EX_A, EX_B,
    input [W-1:0]EX_F_A, EX_F_B,
    input EX_is_JALR, EX_is_JAL,
    output reg [W-1:0]EX_in_A, EX_in_B,
    output reg [W-1:0]EX_read_data_B 
);
    wire [W-1:0] A = (EX_is_FPU) ? EX_F_A : EX_A;
    wire [W-1:0] B = (EX_is_FPU || EX_is_FSW) ? EX_F_B : EX_B;

    reg [W-1:0] fwd_A, fwd_B;
    always @(*) begin
        fwd_A = (EX_is_JAL) ? EX_pc : A;
        if(MEMtoEX_forward==2'b01 || MEMtoEX_forward==2'b10) begin
            fwd_A = MEM_value;
        end
        else if(WBtoEX_forward ==2'b01 || WBtoEX_forward ==2'b10)begin
            fwd_A = WB_value;
        end

        fwd_B = B;
        if(MEMtoEX_forward==2'b01 || MEMtoEX_forward==2'b11)begin
           fwd_B = MEM_value; 
        end
        else if(WBtoEX_forward ==2'b01 || WBtoEX_forward ==2'b11)begin
            fwd_B = WB_value;
        end

        EX_in_A = fwd_A;
        EX_in_B = (EX_is_JAL) ? 32'd4 : (ALUsrc || EX_is_JALR) ? imm : fwd_B;

        EX_read_data_B = (EX_is_FSW || EX_is_SW) ? fwd_B : {W{1'b1}};
    end
endmodule