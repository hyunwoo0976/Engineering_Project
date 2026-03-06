`timescale 1ns/1ps
module dual_port_reg_tb;
    reg [3:0] din;
    reg [1:0] w_add,r_add1,r_add2;
    reg clk, reset, we;
    wire[3:0] dout1,dout2;

    always #5 clk=~clk;

    initial begin
        $dumpfile("dual_port.vcd");
        $dumpvars(0,dual_port_reg_tb);
    end

    dual_port_reg uut(
        .din(din),
        .w_add(w_add),
        .clk(clk),
        .reset(reset),
        .we(we),
        .r_add1(r_add1),
        .r_add2(r_add2),
        .dout1(dout1),
        .dout2(dout2)
    );

    integer i;
    initial begin
        clk=0; reset=1; we=0; r_add1=0; r_add2=0; w_add=0; din=0;
        #11 
        reset=0;
        for(i=0;i<4;i=i+1)begin
            @(posedge clk);
            we=1;
            w_add=i;
            din=$random%16;
        end

        @(posedge clk)
        we=0;
        r_add1=2'b00;
        r_add2=2'b01;

        #10;
        r_add1=2'b10;
        r_add2=2'b11;

        #50
        $finish;
    end
endmodule
            
