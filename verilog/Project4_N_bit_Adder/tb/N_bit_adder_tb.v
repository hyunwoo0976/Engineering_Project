`timescale 1ns/1ps
module N_bit_adder_tb #(parameter N=4);
    reg [N-1:0]x,y;
    reg cin;
    wire[N-1:0]sum;
    wire cout;

    N_bit_adder #(.N(4))uut(
        .a(x),
        .b(y),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    initial begin
        $monitor("Time=%0t | A=%d, B=%d, Cin=%b | Sum=%d, Cout=%b",$time,x,y,cin,sum,cout );
    end

    initial begin
        $dumpfile("N_bit.vcd");
        $dumpvars(0,N_bit_adder_tb);
    end

    integer i;
    initial begin
        x=4'd0; y=4'd0; cin=1'b0;
        #10;
        for(i=0;i<16;i=i+1)begin
            x=i;
            y=15-i;
            cin=0;
            #10;
        end

        x=4'd15; y=4'd1; cin=1'b0;
        #10;

        x=4'hF; y=4'hF; cin=1'b1;
        #10;

        $finish;
    end
endmodule