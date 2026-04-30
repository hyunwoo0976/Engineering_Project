`timescale 1ns/1ps
module FPU_MUL_tb #(parameter W=32);
    reg [W-1:0] IN_A,IN_B;
    reg clk, reset;
    wire OF,UF;
    wire [W-1:0]result_out;

    always #5 clk=~clk;

    initial begin
        $dumpfile("FPU.vcd");
        $dumpvars(0,FPU_MUL_tb);

        $monitor("Time: %0t ns | Reset: %b | IN_A: %h | IN_B: %h || OUT: %h | OF: %b | UF: %b", $time, reset, IN_A, IN_B, result_out, OF, UF);
    end

    FPU_MUL #(.W(32)) fmul(
        .clk(clk),
        .reset(reset),
        .IN_A(IN_A),
        .IN_B(IN_B),
        .result_out(result_out),
        .OF(OF),
        .UF(UF)
    );

    initial begin
        clk=0;
        reset=1;
        IN_A=0;
        IN_B=0;

        #11;
        reset=0;

        IN_A=32'h3FC0_0000;
        IN_B=32'h4000_0000;

        #150;
        $finish;
    end
endmodule