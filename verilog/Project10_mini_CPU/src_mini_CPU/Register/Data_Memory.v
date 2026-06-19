module Data_Memory #(parameter W=32)(
    input clk,
    input MemWrite,
    input MemRead,
    input [W-1:0] addr,
    input [W-1:0] write_data,
    output [W-1:0] read_data
);

    reg [W-1:0]mem[0:1023];
    initial begin
        $readmemh("./verilog/Project10_mini_CPU/memo/data.mem", mem);
    end

    always @(posedge clk)begin
        if(MemWrite)begin
            mem[addr >> 2]<=write_data;
        end
    end
    
    assign read_data=(MemRead) ? mem[addr >> 2] : 32'b0;
endmodule