`timescale 1ns/1ps
module Top_CPU_tb #(parameter W=32);
    reg clk, reset;
    wire [31:0]current_inst;
    wire [31:0]current_pc;
    wire [31:0]wb_data;

    always #30 clk=~clk;

    initial begin
        $dumpfile("CPU.vcd");
        $dumpvars(0,Top_CPU_tb);

        $monitor("Time: %0t ns | Reset: %b  ||  instruction: %h | address: %h | result: %h", $time, reset, current_inst,current_pc,wb_data);
    end

    Top_CPU #(.W(32)) uut(
        .clk(clk),
        .reset(reset),
        .current_inst(current_inst),
        .current_pc(current_pc),
        .wb_data(wb_data)
    );

    initial begin
        clk=0;
        reset=1;

        #28;
        reset=0;

        #2000;
        $finish;
    end
endmodule