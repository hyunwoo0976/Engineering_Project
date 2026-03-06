`timescale 1ns/1ps
module Top_module_tb;
    reg [3:0] ALU0_a, ALU0_b;
    reg [3:0] ALU1_a, ALU1_b;
    wire [5:0] ALU2;
    reg [1:0] mode;
    reg clk,reset;

    always #5 clk =~clk;

    initial begin
        $dumpfile("Top_module.vcd");
        $dumpvars(0,Top_module_tb);
        
        clk=0;
        reset=1;
        #15 reset=0;
    end

    initial begin
        $monitor("Time:%t | mode:%b || ALU0_a=%b, ALU0_b=%b | ALU1_a=%b, ALU1_b=%b || OUTPUT=%d (%b)",$time,mode,ALU0_a,ALU0_b,ALU1_a,ALU1_b,ALU2,ALU2);
    end

    Top_module uut(
        .alu0_a(ALU0_a),
        .alu0_b(ALU0_b),
        .alu1_a(ALU1_a),
        .alu1_b(ALU1_b),
        .alu2(ALU2),
        .clk(clk),
        .reset(reset),
        .mode(mode)
    );

    integer i,j;
    initial begin
        #20;
        for(i=0;i<4;i=i+1) begin
            mode=i;
            for(j=0;j<5;j=j+1) begin
                ALU0_a=$random%16;
                ALU0_b=$random%16;
                ALU1_a=$random%16;
                ALU1_b=$random%16;
                #10;
            end
        end
        $finish;
    end
endmodule

