`timescale 1ns/1ps
module calculate_sub_tb;
    reg [3:0]a,b;
    reg cin;
    wire [3:0]sum;
    wire cout;

    calculate_sub #(.N(4)) uut(
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );
   
    initial begin
        $monitor("Time=%0t | A=%d, B=%d | Result(Sum)=%d, Cout=%b",$time, a, b, sum, cout);
   
    end
   
    initial begin
        $dumpfile("calculate_sub.vcd");
        $dumpvars(0,calculate_sub_tb);
    end

    initial begin
        $display("case1:");
        a=4'd10; b=4'd4; cin=1'b0;
        #10;

        $display("case2:");
        a=4'd1; b=4'd14; cin=1'b0;
        #10;

        $display("case3:");
        a=4'd14; b=4'd8; cin=1'b0;
        #10;

        $display("case4:");
        a=4'd13; b=4'd13; cin=1'b0;
        #10;

        $display("case5:");
        a=4'd10; b=4'd4; cin=1'b1;
        #10;

        $finish;
    end
endmodule      