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
    integer k;
    initial begin
        for(k=0; k<31; k = k + 1)begin
            srf[k] <= 0;
        end
    end
    always @(posedge clk) begin
        if((wb_fregwrite || wb_regwrite) && wb_rd != 5'b0)begin
            srf[wb_rd] <= wb_data;
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

    initial begin
        clk = 0; reset = 1;

        @(negedge clk);
        reset = 0;

        repeat(100) @(posedge clk); // 충분히 오래 (16+5보다 훨씬 많이)

            check(1, 32'h63021AB1);   // f1
            check(2, 32'h5D905439);   // f2
            check(3, 32'h63022CBC);   // f3
            check(4, 32'h630208A6);   // f4
            check(5, 32'hE30208A6);   // f5
            check(6, 32'h7F800000);   // f6
            check(7, 32'h4039999A);   // f7
            check(8, 32'h40666666);   // f8
            check(9, 32'h40D00000);   // f9
            check(10, 32'h40666666);   // f10
            check(11, 32'h41BB3333);   // f11
            check(12, 32'h40666666);   // f12
            check(13, 32'hC039999A);   // f13
            check(14, 32'h3F333330);   // f14
            check(15, 32'hC1166666);   // f15
            check(16, 32'hC0CFFFFF);   // f16
            check(17, 32'h63BCA6B4);   // f17
            check(18, 32'hC14FFFFF);   // f18
        
        $finish;
    end

endmodule