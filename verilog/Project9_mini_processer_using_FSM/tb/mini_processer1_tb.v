`timescale 1ns/1ps
module mini_processer1_tb #(parameter W=4);
    reg clk,reset,we,start;
    reg [1:0]mode;
    reg [1:0]w_add,r_add1,r_add2;
    reg cin;
    reg [W-1:0]din;
    reg d_f;

    always #5 clk=~clk;

    m_top_module #(.W(4))uut(
        .clk(clk),
        .reset(reset),
        .we(we),
        .start(start),
        .mode(mode),
        .cin(cin),
        .w_add(w_add),
        .r_add1(r_add1),
        .r_add2(r_add2),
        .din(din),
        .d_f(d_f)
    );

    initial begin
        $dumpfile("m_pro.vcd");
        $dumpvars(0,mini_processer1_tb);
    end

    integer i,j;

    initial begin
        clk=0; reset=1; we=0; start=0;
        w_add=0; r_add1=0; r_add2=0; 
        mode=0; cin=1'b0; d_f=0;
        #11
        reset=0;
        we=1;
        @(posedge clk);
        w_add=2'b00;
        din=2;

        @(posedge clk);
        w_add=2'b01;
        din=10;

        @(posedge clk);
        we=0;
        r_add1=2'b00;
        r_add2=2'b01;

        #9;
        start=1;

        for(j=0;j<4;j=j+1) begin
            @(posedge clk);
            mode=j;
            if(mode==2'b01)begin
                cin=1'b1;
            end
            else begin
                cin=1'b0;
            end
        end
        @(posedge clk);
        d_f=1;

        #55;
        $finish;
    end
endmodule
