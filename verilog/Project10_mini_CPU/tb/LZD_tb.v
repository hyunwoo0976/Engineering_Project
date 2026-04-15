module LZD_tb #(parameter W=64);
    reg [47:0]Sum;
    reg Cout;
    wire [5:0]count;
    wire all_zero;

    initial begin
        $dumpfile("LZD.vcd");
        $dumpvars(0,LZD_tb); 
    end

    LZD uut0(
        .Sum(Sum),
        .Cout(Cout),
        .count(count),
        .all_zero(all_zero)
    );

    initial begin
        Sum=48'b0;
        Cout=0;
        #10;

        Sum=48'd181474976710625;
        Cout=0;
        #10;

        Sum=48'd000328390283192;
        Cout=1;
        #10;
        
        Sum=48'd000328390283192;
        Cout=0;
        #10;


        Sum=48'b0;
        Cout=0;
        #10;
        
        Sum=48'b0;
        Cout=1;
        #50;

        $finish;
    end
endmodule
