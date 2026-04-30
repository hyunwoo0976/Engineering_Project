`timescale 1ns/1ps
module FPU_ADD_tb #(parameter W=32);
    reg [W-1:0]IN_a,IN_b;
    reg mode,clk,reset;
    wire error,OF,UF;
    wire [W-1:0]result_out;

    always #5 clk=~clk;

    initial begin
        $dumpfile("FPU_ADD.vcd");
        $dumpvars(0,FPU_ADD_tb);
        $monitor("Time: %0t ns | Reset: %b | IN_a: %h | IN_b: %h || OUT: %h | OF: %b | UF: %b", $time, reset, IN_a, IN_b, result_out, OF, UF);
    end

    FPU_ADD #(.W(32))fpu_tb(
        .IN_a(IN_a),
        .IN_b(IN_b),
        .mode(mode),
        .clk(clk),
        .reset(reset),
        .error(error),
        .OF(OF),
        .UF(UF),
        .result_out(result_out)
    );

    initial begin
        clk=0;
        reset=1;
        IN_a=0;
        IN_b=0;
        mode=0;

        #11;
        reset=0;

        IN_a=32'h3FC00000; //1.5
        IN_b=32'h40200000; //2.5
        mode=0;

        #160;
        $finish;
    end

endmodule