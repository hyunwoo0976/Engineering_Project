`timescale 1ns / 1ps
module report_waveform;
    reg clk = 0;
    reg reset = 1;
    reg FPU_en = 0;
    reg [31:0] IN_A = 0;
    reg [31:0] IN_B = 0;
    reg [1:0] op = 0;
    reg [2:0] rm = 0;

    wire [31:0] result_out;
    wire NV, OF, UF, NX, valid_out, error, ZF, sign;
    integer output_count = 0;

    FPU #(.ISOLATE(1)) dut(
        .clk(clk),
        .reset(reset),
        .FPU_en(FPU_en),
        .IN_A(IN_A),
        .IN_B(IN_B),
        .op(op),
        .rm(rm),
        .result_out(result_out),
        .NV(NV),
        .OF(OF),
        .UF(UF),
        .NX(NX),
        .valid_out(valid_out),
        .error(error),
        .ZF(ZF),
        .sign(sign)
    );

    always #5 clk = ~clk;

    task send(input [31:0] input_a, input [31:0] input_b, input [1:0] input_op, input [2:0] input_rm);
        begin
            @(negedge clk);
            FPU_en = 1'b1;
            IN_A = input_a;
            IN_B = input_b;
            op = input_op;
            rm = input_rm;
        end
    endtask

    always @(posedge clk)begin
        #1;
        if(valid_out)begin
            case(output_count)
                0: if(result_out !== 32'h40700000 || {NV, OF, UF, NX} !== 4'b0000) $fatal(1, "normal ADD mismatch");
                1: if(result_out !== 32'h7fc00000 || {NV, OF, UF, NX} !== 4'b1000) $fatal(1, "Inf-Inf mismatch");
                2: if(result_out !== 32'h7f800000 || {NV, OF, UF, NX} !== 4'b0101) $fatal(1, "overflow mismatch");
                3: if(result_out !== 32'h00000002 || {NV, OF, UF, NX} !== 4'b0000) $fatal(1, "subnormal mismatch");
                default: $fatal(1, "unexpected output");
            endcase
            output_count = output_count + 1;
        end
    end

    initial begin
        $dumpfile("report_waveform.vcd");
        $dumpvars(0, report_waveform);

        repeat(2) @(negedge clk);
        reset = 1'b0;

        send(32'h3fc00000, 32'h40100000, 2'd0, 3'd0);  // 1.5 + 2.25 = 3.75
        send(32'h7f800000, 32'h7f800000, 2'd1, 3'd0);  // Inf - Inf = qNaN, NV
        send(32'h7f7fffff, 32'h7f7fffff, 2'd0, 3'd0);  // overflow = Inf, OF/NX
        send(32'h00000001, 32'h00000001, 2'd0, 3'd0);  // exact subnormal result

        @(negedge clk);
        FPU_en = 1'b0;
        IN_A = 0;
        IN_B = 0;
        op = 0;
        rm = 0;

        wait(output_count == 4);
        repeat(2) @(negedge clk);
        $display("REPORT WAVEFORM PASS 4");
        $finish;
    end

    initial begin
        #300;
        $fatal(1, "timeout");
    end
endmodule
