`timescale 1ns/1ps
//iverilog -g2012 -s Testbench_port_MUX -o test.out -f ./verilog/Project10_mini_CPU/F_file/F_file.f
module Testbench_port_MUX #(parameter W=32);
    reg [1:0]MEMtoEX_forward, WBtoEX_forward;
    reg [W-1:0]MEM_value, WB_value;
    reg [W-1:0]imm;
    reg ALUsrc;
    reg [W-1:0]EX_A, EX_B;
    reg [W-1:0]EX_F_A, EX_F_B;
    reg EX_is_JALR, EX_is_FPU, EX_is_FSW, EX_is_SW;
    
    wire [W-1:0]EX_in_A, EX_in_B;
    wire [W-1:0]EX_read_data;

    port_MUX #(.W(32)) u_port_MUX(
        .MEMtoEX_forward(MEMtoEX_forward), .WBtoEX_forward(WBtoEX_forward),
        .MEM_value(MEM_value), .WB_value(WB_value),
        .imm(imm),
        .ALUsrc(ALUsrc),
        .EX_A(EX_A), .EX_B(EX_B),
        .EX_F_A(EX_F_A), .EX_F_B(EX_F_B),
        .EX_is_JALR(EX_is_JALR), .EX_is_FPU(EX_is_FPU),
        .EX_is_FSW(EX_is_FSW), .EX_is_SW(EX_is_SW),
    
        .EX_in_A(EX_in_A), .EX_in_B(EX_in_B),
        .EX_read_data_B(EX_read_data)
    );
        wire [W-1:0] A = (EX_is_FPU) ? EX_F_A : EX_A;
        wire [W-1:0] B = (EX_is_FPU || EX_is_FSW) ? EX_F_B : EX_B;

    initial begin
        $dumpfile("test.vcd");
        $dumpvars(0,Testbench_port_MUX);
    end

    task clr;
        begin
            MEMtoEX_forward = 0; WBtoEX_forward = 0; MEM_value = 0; WB_value = 0; imm = 0; ALUsrc = 0; EX_A = 0; EX_B = 0; EX_is_JALR = 0;
            EX_F_A = 0; EX_F_B = 0; EX_is_FPU = 0; EX_is_FSW = 0; EX_is_SW = 0;
        end
    endtask

    function [3*W-1:0] ref_model;
        reg[W-1:0] a, b, c;
        reg [W-1:0] fwd_A, fwd_B;
        begin
            fwd_A = A;
            if(MEMtoEX_forward==2'b01 || MEMtoEX_forward==2'b10) begin
                fwd_A = MEM_value;
            end
            else if(WBtoEX_forward ==2'b01 || WBtoEX_forward ==2'b10)begin
                fwd_A = WB_value;
            end

            fwd_B = B;
            if(MEMtoEX_forward==2'b01 || MEMtoEX_forward==2'b11)begin
            fwd_B = MEM_value; 
            end
            else if(WBtoEX_forward ==2'b01 || WBtoEX_forward ==2'b11)begin
                fwd_B = WB_value;
            end

            a = fwd_A;
            b = (ALUsrc || EX_is_JALR) ? imm : fwd_B;

            c = (EX_is_FSW || EX_is_SW) ? fwd_B : {W{1'b1}};
            
            ref_model = {a, b, c};
        end
    endfunction


    
    integer PASS, FAIL, count;
    reg [31:0] fin_A, fin_B, fin_C;
    initial begin
        PASS = 0; FAIL = 0; count = 1;
        repeat(500)begin
            clr;
            MEMtoEX_forward = {$random} % 4;
            WBtoEX_forward = {$random} % 4;
            if({MEMtoEX_forward, WBtoEX_forward} == 4'b000)begin
                $display("ERROR");
            end
            case({$random} % 6)
                0: begin /* R-type */  ALUsrc=0; end
                1: begin /* I-type */  ALUsrc=1; end
                2: begin EX_is_SW=1;   ALUsrc=1; end
                3: begin EX_is_FPU=1;  ALUsrc=0; end
                4: begin EX_is_FSW=1;  ALUsrc=1; end
                5: begin EX_is_JALR=1; ALUsrc=1; end
        endcase
            ALUsrc = {$random} % 2;

            EX_A = {$random} % 31;
            EX_B = {$random} % 31;
            EX_F_A = {$random} % 31;
            EX_F_B = {$random} % 31;
            imm = {$random} % 31;
            MEM_value = {$random} % 31;
            WB_value = {$random} % 31;

            #1;
            {fin_A, fin_B, fin_C} = ref_model();

            if(EX_in_A != fin_A || EX_in_B != fin_B || EX_read_data != fin_C)begin
                $display("[FAIL] / %0d", count);
                $display("got EX_in_A = %h, EX_in_B = %h | exp fin_A = %h, fin_B = %h, fin_C = %h",EX_in_A, EX_in_B, fin_A, fin_B, fin_C);
                $display("EX_A = %h, EX_B = %h", EX_A, EX_B);
                $display("EX_is_JALR = %b", EX_is_JALR);
                $display("EX_is_FPU = %b", EX_is_FPU);
                $display("EX_is_SW = %b, EX_is_FSW = %b", EX_is_SW, EX_is_FSW);
                $display("MEMtoEX_forward = %b | WBtoEX_forward = %b", MEMtoEX_forward, WBtoEX_forward);
                $display("ALUsrc = %b", ALUsrc);
                $display("imm = %h", imm);
                $display("MEM_value = %h, WB_value = %h", MEM_value, WB_value);
                FAIL = FAIL + 1;
                count = count + 1;
            end
            else begin
                $display("[PASS] / %0d", count);
                if(EX_is_JALR)begin
                    $display("got EX_in_A = %h, EX_in_B = %h | exp fin_A = %h, fin_B = %h, fin_C = %h",EX_in_A, EX_in_B, fin_A, fin_B, fin_C);
                    $display("EX_A = %h, EX_B = %h", EX_A, EX_B);
                    $display("EX_is_JALR = %b", EX_is_JALR);
                    $display("EX_is_FPU = %b", EX_is_FPU);
                    $display("EX_is_SW = %b, EX_is_FSW = %b", EX_is_SW, EX_is_FSW);
                    $display("MEMtoEX_forward = %b | WBtoEX_forward = %b", MEMtoEX_forward, WBtoEX_forward);
                    $display("ALUsrc = %b", ALUsrc);
                    $display("imm = %h", imm);
                    $display("MEM_value = %h, WB_value = %h", MEM_value, WB_value);
                end
                PASS = PASS + 1;
                count = count + 1;
            end
        end
        $display("[PASS] = %0d | [FAIL] = %0d", PASS, FAIL);
        $display("PASS -> %0dper || FAIL -> %0dper", PASS/5, FAIL/5);
        $finish;
    end
endmodule






