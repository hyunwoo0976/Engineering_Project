`timescale 1ns/1ps
module shift_reg_tb #(parameter W=32);
    reg [W-1:0]D_in;
    reg clk,load,reset,shift;
    wire [W-1:0]D_out;
    wire fin;

    always #5 clk=~clk;

    Top_register #(.W(32))uut0(
        .D_in(D_in),
        .clk(clk),
        .reset(reset),
        .load(load),
        .shift(shift),
        .D_out(D_out),
        .fin(fin)
    );

    initial begin
        $dumpfile("Shift_register.vcd");
        $dumpvars(0,shift_reg_tb);
    end

    integer i;
    initial begin
        clk=0; reset=1; load=0; shift=0;
        #15;
        reset=0;
        D_in=32'hA5A5_F0F0;
        
        @(posedge clk);
        load=1;
        
        @(posedge clk);
        load=0;
        shift=1;

        wait(fin==1'b1);

        @(posedge clk);
        shift=0;
        #20;
        $finish;

    end
endmodule