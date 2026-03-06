`timescale 1ns/1ps
module shift_reg_tb #(parameter W=4);
    reg [W-1:0]a;
    reg clk,load,reset;
    wire N;

    always #5 clk=~clk;

    shift_reg #(.W(4))uut0(
        .D_a(a),
        .N(N),
        .clk(clk),
        .reset(reset),
        .load(load)
    );

    initial begin
        $dumpfile("reg.vcd");
        $dumpvars(0,shift_reg_tb);
    end

    integer i;
    initial begin
        clk=0; reset=1; load=0;
        #9;
        reset=0;
        a=5;
        load=1;

        for(i=0;i<4;i=i+1)begin
            @(posedge clk);
            load=0;
        end

        #10;
        $finish;
    end
endmodule