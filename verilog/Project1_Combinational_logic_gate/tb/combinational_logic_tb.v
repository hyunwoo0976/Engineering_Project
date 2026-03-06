`timescale 1ns/1ps
module combinational_logic_tb;
    reg a,b,c;
    reg a1,b1,c1;
    wire f;
    wire f1;

    initial begin
        $dumpfile("com_b.vcd");
        $dumpvars(0,combinational_logic_tb);
    end

    combinational_logic uut0(
        .x(a),
        .y(b),
        .z(c),
        .f(f)
    );

    standard_logic uut1(
        .x(a1),
        .y(b1),
        .z(c1),
        .f(f1)
    );

    integer i;
    initial begin
        for(i=0;i<8;i=i+1)begin
            {a,b,c}=i;
            {a1,b1,c1}=i;
            #10;
        end
        $finish;
    end
endmodule