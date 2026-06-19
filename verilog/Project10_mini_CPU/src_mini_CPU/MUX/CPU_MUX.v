module CPU_MUX #(parameter W=32)(
    input [W-1:0]ALU_result,
    input [W-1:0]mem_read_data,
    input MemtoReg,
    output reg [W-1:0]OUT
);

    always @(*)begin
        if(MemtoReg)begin
            OUT = mem_read_data;
        end
        else begin
            OUT = ALU_result;
        end
    end
    
endmodule