`timescale 1ns / 1ps
module fp32_regression;
    reg clk = 0, reset = 1, en = 0;
    always #5 clk = ~clk;
    reg [31:0] a = 0, b = 0;
    reg [1:0] op = 0;
    reg [2:0] rm = 0;
    wire [31:0] r0, r1;
    wire [4:0] f0, f1;
    wire v0, v1, er0, er1, z0, z1, s0, s1;
    FPU #(.ISOLATE(0)) plain(
        .clk(clk),
        .reset(reset),
        .FPU_en(en),
        .IN_A(a),
        .IN_B(b),
        .op(op),
        .rm(rm),
        .result_out(r0),
        .NV(f0[4]),
        .OF(f0[2]),
        .UF(f0[1]),
        .NX(f0[0]),
        .valid_out(v0),
        .error(er0),
        .ZF(z0),
        .sign(s0)
    );
    FPU #(.ISOLATE(1)) isolated(
        .clk(clk),
        .reset(reset),
        .FPU_en(en),
        .IN_A(a),
        .IN_B(b),
        .op(op),
        .rm(rm),
        .result_out(r1),
        .NV(f1[4]),
        .OF(f1[2]),
        .UF(f1[1]),
        .NX(f1[0]),
        .valid_out(v1),
        .error(er1),
        .ZF(z1),
        .sign(s1)
    );
    assign f0[3] = 0;
    assign f1[3] = 0;
    reg [31:0] expected, eq[0:6];
    reg [4:0] ef, fq[0:6];
    reg ee, erq[0:6];
    reg [6:0] vq = 0;
    integer fd, rc, i, pass = 0, cycles = 0;
    reg [1023:0] path;
    always @(posedge clk)begin
        if(reset)begin
            vq = 0;
            for(i = 0; i < 7; i = i + 1)begin
                eq[i] = 0;
                fq[i] = 0;
                erq[i] = 0;
            end
        end
        else begin
            for(i = 6; i > 0; i = i - 1)begin
                eq[i] = eq[i-1];
                fq[i] = fq[i-1];
                erq[i] = erq[i-1];
            end
            eq[0] = expected;
            fq[0] = ef;
            erq[0] = ee;
            vq = {vq[5:0], en};
        end
        #1;
        if(v0 !== vq[6] || v1 !== vq[6]) $fatal(1, "LATENCY cycle=%0d", cycles);
        if(vq[6])begin
            if((f0[1] && !f0[0]) || (f1[1] && !f1[0])) $fatal(1, "UF without NX");
            if(r0 !== eq[6] || r1 !== eq[6] || f0 !== fq[6] || f1 !== fq[6] || er0 !== erq[6] || er1 !== erq[6])
                $fatal(
                    1,
                    "FP mismatch cycle=%0d plain=%h isolated=%h exp=%h flags=%h/%h expflags=%h",
                    cycles,
                    r0,
                    r1,
                    eq[6],
                    f0,
                    f1,
                    fq[6]
                );
            if(z0 !== (eq[6][30:0] == 0) || z1 !== z0 || s0 !== eq[6][31] || s1 !== s0) $fatal(1, "sideband");
            pass = pass + 1;
        end
        cycles = cycles + 1;
        if(cycles % 5000 == 0) $display("progress cycles=%0d checked=%0d", cycles, pass);
    end
    initial begin
        if(!$value$plusargs("VECTORS=%s", path)) $fatal(1, "missing vectors");
        if($test$plusargs("VCD"))begin
            $dumpfile("activity.vcd");
            $dumpvars(0, plain, isolated);
        end
        fd = $fopen(path, "r");
        if(!fd) $fatal(1, "vectors open failed");
        @(negedge clk);
        reset = 0;
        while(!$feof(
            fd
        ))begin
            @(negedge clk);
            rc = $fscanf(fd, "%h %h %h %h %h %h %h %h %h\n", reset, en, a, b, op, rm, expected, ef, ee);
            if(rc != 9) $fatal(1, "bad vector row %0d", rc);
        end
        @(negedge clk);
        en = 0;
        reset = 0;
        repeat(8) @(negedge clk);
        $display("FP PASS checked=%0d cycles=%0d", pass, cycles);
        $finish;
    end
    initial begin
        #20000000;
        $fatal(1, "timeout");
    end
endmodule
