module Register_file #(parameter W=32)(
    input [W-1:0]we_data,
    input [4:0] we_addr,
    input [4:0] Rs1_addr,Rs2_addr,Rt_addr,
    input clk, reset,we,
    output [W-1:0]Rs1_data,Rs2_data,Rt_data
);

    reg[W-1:0]mem[0:31];

    integer i;
    always @(posedge clk or posedge reset)begin
        if(reset)begin
            for(i=0;i<32;i=i+1)begin
                mem[i]<=32'b0;
            end
        end
        else begin
            if(we&&(we_addr !=5'd0))begin
                mem[we_addr]<=we_data;
            end
        end
    end

    assign Rs1_data=(Rs1_addr==5'd0)?mem[0]:mem[Rs1_addr];
    assign Rs2_data=(Rs2_addr==5'd0)?mem[0]:mem[Rs2_addr];
    assign Rt_data=(Rt_addr==5'd0)?mem[0]:mem[Rt_addr];
endmodule