`timescale 1ns / 1ps
module cpu_fp_special;
    reg clk = 0, reset = 1;
    always #5 clk = ~clk;
    Pipeline_CPU dut(
        .clk(clk),
        .reset(reset)
    );
    integer i;
    function [31:0] flw(input integer rd, offset);
        flw = (offset << 20) | (2 << 12) | (rd << 7) | 7'h07;
    endfunction
    function [31:0] fp(input integer rd, ra, rb, funct7);
        fp = (funct7 << 25) | (rb << 20) | (ra << 15) | (rd << 7) | 7'h53;
    endfunction
    task check(input integer rd, input [31:0] value);
        if(dut.u_FPU_Regfile.mem[rd] !== value)
            $fatal(1, "f%0d actual=%h expected=%h", rd, dut.u_FPU_Regfile.mem[rd], value);
    endtask
    initial begin
        #1;
        for(i = 0; i < 128; i = i + 1) dut.u_IMEM.mem[i] = 32'h00000013;
        dut.u_Data_Memory.mem[0] = 32'h3f800000;
        dut.u_Data_Memory.mem[1] = 32'h40000000;
        dut.u_Data_Memory.mem[2] = 32'h7f800000;
        dut.u_Data_Memory.mem[3] = 32'h00000001;
        dut.u_IMEM.mem[0] = flw(0, 0);
        dut.u_IMEM.mem[1] = fp(1, 0, 0, 0);  // immediate FLW f0 -> dependent FADD
        dut.u_IMEM.mem[2] = flw(2, 4);
        dut.u_IMEM.mem[3] = fp(0, 1, 2, 8);  // write f0 again, 2*2 = 4
        dut.u_IMEM.mem[4] = fp(3, 0, 1, 0);  // consume in-flight f0, 4+2 = 6
        dut.u_IMEM.mem[5] = flw(4, 8);
        dut.u_IMEM.mem[6] = fp(5, 4, 4, 4);  // Inf-Inf = canonical NaN
        dut.u_IMEM.mem[7] = flw(6, 12);
        dut.u_IMEM.mem[8] = fp(7, 6, 6, 0);  // subnormal+subnormal = bit pattern 2
        dut.u_IMEM.mem[9] = 32'h0000006f;
        @(negedge clk);
        reset = 0;
        repeat(160) @(negedge clk);
        check(0, 32'h40800000);
        check(1, 32'h40000000);
        check(3, 32'h40c00000);
        check(5, 32'h7fc00000);
        check(7, 32'h00000002);
        if(dut.u_Regfile.mem[0] !== 0) $fatal(1, "x0 corrupted");
        $display("CPU special/f0 PASS 6");
        $finish;
    end
endmodule
