module Top_module_tb #(parameter W=32);
    reg clk, reset;
    reg [1:0]op;
    reg [W-1:0]IN_A,IN_B;
    wire [W-1:0]result_out;
    wire error,OF,UF;

    always #5 clk=~clk;

    initial begin
        $dumpfile("Top_module.vcd");
        $dumpvars(0,Top_module_tb);

        $monitor("Time: %0t ns | Reset: %b | OP:%b | IN_a: %h | IN_b: %h || OUT: %h | OF: %b | UF: %b | error:%b", $time, reset, op, IN_A, IN_B, result_out, OF, UF, error);
    end
    integer i;
    reg rand_SIGN;
    reg [7:0]rand_EXPO;
    reg [22:0]rand_FRAC;

    initial begin
        clk=0;
        reset=1;
        op=2'b00;
        IN_A=32'd0;
        IN_B=32'd0;

        #30;

        reset=0;

        for(i=0;i<200;i=i+1)begin
            @(negedge clk);
            rand_SIGN=$urandom%2;
            rand_EXPO=$urandom_range(120,135);
            rand_FRAC=$urandom;
            IN_A={rand_SIGN,rand_EXPO,rand_FRAC};
            
            rand_SIGN=$urandom%2;
            rand_EXPO=$urandom_range(120,135);
            rand_FRAC=$urandom;
            IN_B={rand_SIGN,rand_EXPO,rand_FRAC};

            op=$urandom_range(0,2);
        end
        repeat(10) @(posedge clk);
        $display("Test finished!");
        $finish;
    end
endmodule