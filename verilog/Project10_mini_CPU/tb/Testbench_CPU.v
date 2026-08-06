`timescale 1ns/1ps
module Testbench_CPU #(parameter W=32);
    reg clk, reset;
    wire [W-1:0]current_pc;
    wire [W-1:0]current_inst;
    wire [W-1:0]wb_data;
    wire [4:0]wb_rd;
    wire wb_fregwrite, wb_regwrite;
    wire wb_FPU_OF, wb_FPU_UF;

    always #5 clk = ~clk;

    initial begin
        $dumpfile("test.vcd");
        $dumpvars(0,Testbench_CPU);
    end

    Pipeline_CPU #(.W(32))u_Pipeline_CPU(
        .clk(clk), .reset(reset),
        .current_pc(current_pc), .current_inst(current_inst),
        .wb_data(wb_data), .wb_regwrite(wb_regwrite), .wb_fregwrite(wb_fregwrite), .wb_rd(wb_rd),
        .wb_FPU_OF(wb_FPU_OF), .wb_FPU_UF(wb_FPU_UF)
    );
        
    reg [31:0] srf [0:31];
    reg [31:0] srf_f [0:31];

    integer i, j;
    initial begin
        for(i=0; i<31; i = i + 1)begin
            srf[i] <= 0;
            srf_f[i] <= 0;
        end
    end

    always @(posedge clk) begin
        if((wb_regwrite) && wb_rd != 5'b0)begin
            srf[wb_rd] <= wb_data;
        end
        if((wb_fregwrite) && wb_rd != 5'b0)begin
            srf_f[wb_rd] <= wb_data;
        end
    end

    task check;
        input [4:0]  r;
        input [31:0] exp;
        begin
            if (srf[r] !== exp) $display("[FAIL] x%0d = %h, exp %h", r, srf[r], exp);
            else $display("[PASS] x%0d = %h", r, srf[r]);
        end
    endtask

    task check_f;
        input [4:0]  r;
        input [31:0] exp;
        begin
            if (srf_f[r] !== exp) $display("[FAIL] x%0d = %h, exp %h", r, srf_f[r], exp);
            else $display("[PASS] x%0d = %h", r, srf_f[r]);
        end
    endtask

    initial begin
        clk = 0; reset = 1;

        @(negedge clk);
        reset = 0;

        repeat(100) @(posedge clk); // 충분히 오래 (16+5보다 훨씬 많이)
            check(1, 20);
            check(2, 22);
            check(3, 2);
            check(4, -2);
            check(5, 20);
            check(6, 18);
            check(7, 18);
            check(8, 22);
            check(9, 4);
            check(10, 22);
            check(11, 42);
            check(12, 62);
            check(13, 4);
            check(14, 8);
            check(15, 0);
            check(16, -8);

            $display("===================================================================");
            
            check_f(1, 32'h40066666);   // f1
            check_f(2, 32'h40733333);   // f2
            check_f(3, 32'h40BCCCCC);   // f3
            check_f(4, 32'h40733332);   // f4
            check_f(5, 32'hC0066666);   // f5
            check_f(6, 32'hC08D1EB7);   // f6
            check_f(7, 32'h41035C28);   // f7
            check_f(8, 32'h40733332);   // f8
            check_f(9, 32'h40FF5C27);   // f9
            check_f(10, 32'h41200000);   // f10
            check_f(11, 32'h4217FFFF);   // f11
            check_f(12, 32'h43BDFFFF);   // f12
            check_f(13, 32'h456D7FFF);   // f13
            check_f(14, 32'h456D7FFF);   // f14
            check_f(15, 32'h45ED7FFF);   // f15
            check_f(16, 32'h00000000);   // f16
            check_f(17, 32'hC5ED7FFF);   // f17
        
        $finish;
    end

endmodule