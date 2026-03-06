`timescale 1ns/1ps
module Top_system_tb #(parameter N=4);
    reg clk, reset,we,count;
    reg[1:0]mode;
    reg[1:0]w_add,r_add1,r_add2;
    reg[N-1:0]TB_v;

    always #5 clk=~clk;

    initial begin
        $dumpfile("top_sys.vcd");
        $dumpvars(0,Top_system_tb);
        $dumpvars(0, uut.uut0.mem[0]);
        $dumpvars(0, uut.uut0.mem[1]);
        $dumpvars(0, uut.uut0.mem[2]);
    end

    Top_system #(.N(4))uut(
        .r_add1(r_add1), .r_add2(r_add2),
        .w_add(w_add),
        .mode(mode), .TB_v(TB_v),
        .clk(clk), .reset(reset),
        .we(we),
        .count(count)
    );

    integer  i;

    initial begin
        reset=1; clk=0; we=0;
        r_add1=0; r_add2=0; w_add=0; count=0;
        TB_v=0;
        #11
        reset=0;
        
        @(posedge clk);
         we = 1; count = 0;
        w_add = 2'b00;
        TB_v = $random % 16;

        @(posedge clk);
        #1;
        we = 1; count = 0;
        w_add = 2'b01;
        TB_v = $random % 16;
        
        @(posedge clk);
        #1;
        we=0;
        r_add1=2'b00;
        r_add2=2'b01;

        #10;
        count=1;
        for(i=0;i<4;i=i+1)begin
            @(posedge clk);
            mode=i;
            w_add=2'b10;
            we=1;

            @(posedge clk);
            #1;
            we=0;
        end
        $finish;
    end
endmodule    