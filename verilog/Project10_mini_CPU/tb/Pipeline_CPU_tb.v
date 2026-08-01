`timescale 1ns/1ps
module Pipeline_CPU_tb #(parameter W=32);
    reg clk, reset;
    wire [W-1:0]current_inst;
    wire [W-1:0]current_pc;
    wire [W-1:0]inst, pc, wb_data;
    wire wb_FPU_OF, wb_FPU_UF;

    always #5 clk=~clk;

    wire [W-1:0]delayed_pc;

    initial begin
        $dumpfile("CPU.vcd");
        $dumpvars(0,Pipeline_CPU_tb);

        $monitor("Time: %0t ns | Reset: %b  ||  instruction: %h | address: %h | result: %h", $time, reset, current_inst, current_pc, wb_data);
    end

    Pipeline_CPU #(.W(32)) uut(
        .clk(clk),
        .reset(reset),
        .current_inst(current_inst),
        .current_pc(current_pc),
        .wb_data(wb_data),
        .wb_FPU_OF(wb_FPU_OF),
        .wb_FPU_UF(wb_FPU_UF)
    );

    Pipe_reg_3clk #(.W(64))uut_reg0(
        .clk(clk),
        .reset(reset),
        .D({current_inst, current_pc}),
        .Q({inst, delayed_pc})
    );
    Pipe_reg_1clk #(.W(32))uut_reg1(
        .clk(clk),
        .reset(reset),
        .D(delayed_pc),
        .Q(pc)
    );

    initial begin
        clk=0;
        reset=1;

        repeat(2) @(negedge clk);
        reset=0;

        #200;
        $finish;
    end
endmodule