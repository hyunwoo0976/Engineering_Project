`timescale 1ns/1ps
module calculate_add_tb;
    reg x,y,cin;
    wire sum,cout;

    calculate_adder uut(
        .x(x),
        .y(y),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    initial begin
        $monitor("a=%b, b=%b, cin=%b | sum=%b, cout=%b",x,y,cin,sum,cout);
    end

    initial begin
        $dumpfile("calculate.vcd");
        $dumpvars(0,calculate_add_tb);
    end

    integer i;

    initial begin
        for(i=0;i<8;i=i+1)begin
            {x,y,cin}=i;
            #10;
        end
        $finish;
    end
endmodule
