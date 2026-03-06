`timescale 1ns/1ps
module register_file_tb;
    reg [3:0] din;
    reg [3:0] mem[0:3];
    reg [1:0]add;
    reg we,clk,reset;
    wire [3:0] dout;

    always #5 clk=~clk;

    initial begin
        $dumpfile("reg.vcd");
        $dumpvars(0,register_file_tb);
    end

    register_file uut(
        .din(din),
        .dout(dout),
        .add(add),
        .we(we),
        .clk(clk),
        .reset(reset)
    );

    integer i;
    initial begin
        reset=1; clk=0; we=0;
        #10 
        reset =0;
        for(i=0;i<4;i=i+1)begin
            @(posedge clk);
            we=1;
            add=i;
            din=$random%16;
        end
        #10 
        we=0;
        for(i=0;i<4;i=i+1) begin
            #10 
            add=i;
        end
        #50 $finish;
    end
endmodule
