module CPU_MUX #(parameter W=32)(
    input [W-1:0]ALU_result,
    input [W-1:0]mem_read_data,
    input MemtoReg,
    output [W-1:0]OUT
);

    assign OUT = (MemtoReg) ? mem_read_data : ALU_result;
endmodule