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

        repeat(500) @(posedge clk); 
            // ===== ���� =====
            check(1, 32'h00000040);
            check(2, 32'h0000003F);
            check(3, 32'h00000042);
            check(5, 32'h000001C4);
            check(6, 32'h0000000C);
            check(7, 32'h00000004);
            check(8, 32'h00000058);
            check(9, 32'h00000059);
            check(10, 32'hFFFFFF00);
            check(11, 32'hFFFFFFF0);
            check(12, 32'hFFFFFF43);
            check(13, 32'h0000013B);
            check(14, 32'h000000FF);
            check(15, 32'h00000040);
            check(16, 32'h0000005A);
            check(17, 32'h00000037);
            check(18, 32'h0000002B);
            check(19, 32'h0000002C);
            check(20, 32'h0000002D);
            check(21, 32'h0000002E);
            check(23, 32'h0000000C);
            check(24, 32'h0000016C);
            check(25, 32'h0000007F);
            check(26, 32'h0000004D);
            check(27, 32'h00000063);
            check(28, 32'h0000000B);
            check(29, 32'h000001AC);
            check(30, 32'h0000004B);
            check(31, 32'h00000037);
            // ===== �Ǽ� (TB�� FPüũ �Լ���) =====
            $display("================================");
            check_f(1, 32'h7F7FC99E);
            check_f(2, 32'h41200000);
            check_f(3, 32'h3F000000);
            check_f(4, 32'h7F800000);
            check_f(5, 32'h41280000);
            check_f(6, 32'h41200000);
            check_f(7, 32'h42C80000);
            check_f(8, 32'h43480000);
            check_f(10, 32'h43528000);
            check_f(11, 32'h43480000);
            check_f(12, 32'h43528000);
            check_f(13, 32'h40A00000);
            check_f(14, 32'h41A00000);
            check_f(15, 32'h41200000);
            check_f(16, 32'h42C80000);
            check_f(17, 32'h41F00000);
            check_f(18, 32'h40A00000);
            check_f(19, 32'h42C80000);
            check_f(20, 32'h42DC0000);
            check_f(21, 32'h41180000);
            check_f(22, 32'h40A00000);
            check_f(23, 32'h41A00000);
            check_f(24, 32'h3E800000);
            check_f(25, 32'h7F800000);
            check_f(26, 32'h3F000000);
            check_f(27, 32'h3F000000);
            check_f(28, 32'h40800000);
            check_f(29, 32'h40C00000);
            check_f(30, 32'h42C80000);
            check_f(31, 32'h40000000);
        $finish;
    end

endmodule