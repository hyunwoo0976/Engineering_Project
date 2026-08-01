`timescale 1ns/1ps
module Testbench_CPU #(parameter W=32);
    reg clk, reset;
    wire [W-1:0]current_pc;
    wire [W-1:0]current_inst;
    wire [W-1:0]wb_data;
    wire [4:0]wb_rd;
    wire wb_regwrite;
    wire wb_FPU_OF, wb_FPU_UF;

    always #5 clk = ~clk;

    initial begin
        $dumpfile("test.vcd");
        $dumpvars(0,Testbench_CPU);
    end

    Pipeline_CPU #(.W(32))u_Pipeline_CPU(
        .clk(clk), .reset(reset),
        .current_pc(current_pc), .current_inst(current_inst),
        .wb_data(wb_data), .wb_regwrite(wb_regwrite), .wb_rd(wb_rd),
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
        if(wb_regwrite && wb_rd != 5'b0)begin
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

        check(1,  -4);
        check(2,   5);
        check(3,   1);
        check(4,   3);
        check(5,   2);
        check(6,  -1);
        check(7,   1);
        check(8,  12);   // 3<<2  (아까 고친 값!)
        check(9,  16);   // 2<<3
        check(10,  1);   // srl을 x3로 고쳤다면
        check(11,  1);
        check(12, -2);
        check(13,  1);
        check(14,  2);
        check(15,  1);
        check(16,  2);
        
        $finish;
    end

endmodule