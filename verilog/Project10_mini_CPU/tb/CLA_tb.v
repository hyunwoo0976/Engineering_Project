`timescale 1ns/1ps
module CLA_tb #(parameter W=32);
    reg [W-1:0]shift_FRAC_A,shift_FRAC_B;
    reg Cin;
    wire Cout;
    wire [W-1:0]Sum;

    initial begin
        $dumpfile("CLA.vcd");
        $dumpvars(0,CLA_tb);
    end

    CLA uut0(
        .shift_FRAC_A(shift_FRAC_A),
        .shift_FRAC_B(shift_FRAC_B),
        .Cin(Cin),
        .Cout(Cout),
        .Sum(Sum)
    );

    initial begin
        shift_FRAC_A=0;
        shift_FRAC_B=0;
        Cin=0;

        #10;

        shift_FRAC_A=30;
        shift_FRAC_B=42;

        #50;
    end
endmodule
    