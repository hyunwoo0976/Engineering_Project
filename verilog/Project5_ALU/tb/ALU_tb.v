`timescale 1ns/1ps
module ALU_tb;
    reg [3:0] x,y;
    reg [1:0] mode;
    reg cin;
    wire[3:0] result;
    wire cout;

    initial begin
        $monitor("mode=%b | a=%b, b=%b, cin=%b | sum=%b, result=%b", mode,x,y,cin,result,cout);
    end

    initial begin
        $dumpfile("ALU.vcd");
        $dumpvars(0,ALU_tb);
    end

    alu_Nbit uut(
        .a(x),
        .b(y),
        .cin(cin),
        .mode(mode),
        .cout(cout),
        .result(result)
    );

    integer i,j;
    initial begin
        for(i=0;i<4;i=i+1)begin
            mode=i;
            for(j=0;j<10;j=j+1)begin
                x=$random;
                y=$random;
                cin=1'b0;
                #10;
            end
        end
    end
endmodule

