module Data_Memory #(parameter W=32)(
    input clk, reset,
    input MemWrite,
    input MemRead,
    input [W-1:0] addr,
    input [W-1:0] write_data,
    output [W-1:0] read_data
);

    reg [W-1:0]mem[0:31];

    integer i;
    wire [4:0] index = addr[6:2];

    always @(posedge clk or posedge reset)begin
        if(reset)begin
            for(i=0; i<W; i=i+1)begin
                mem[i]<=32'b0;
            end
        end
        else if(MemWrite)begin
            mem[index]<=write_data;
        end
    end
    
    assign read_data=(MemRead) ? mem[index] : 32'b0;
endmodule