`timescale 1ns/1ps
module Testbench_Forwarding_Unit;
    reg MEM_RegWrite, WB_RegWrite;
    reg MEM_FRegWrite, WB_FRegWrite;
    reg EX_uses_Rs1, EX_uses_Rs2, EX_uses_FRs1, EX_uses_FRs2;
    reg EX_is_FPU, EX_is_FLW, EX_is_FSW;
    reg [4:0] MEM_Rd, WB_Rd;
    reg [4:0] EX_Rs1, EX_Rs2;
    wire [1:0] MEMtoEX_forward;
    wire [1:0] WBtoEX_forward;

    initial begin
        $dumpfile("test.vcd");
        $dumpvars(0,Testbench);
    end

    Forwarding_Unit u_CPU_FW(
        .MEM_RegWrite(MEM_RegWrite), .WB_RegWrite(WB_RegWrite),
        .MEM_FRegWrite(MEM_FRegWrite), .WB_FRegWrite(WB_FRegWrite),
        .EX_is_FPU(EX_is_FPU), .EX_is_FLW(EX_is_FLW), .EX_is_FSW(EX_is_FSW),
        .MEM_Rd(MEM_Rd), .WB_Rd(WB_Rd),
        .EX_Rs1(EX_Rs1), .EX_Rs2(EX_Rs2),
        .EX_uses_Rs1(EX_uses_Rs1), .EX_uses_Rs2(EX_uses_Rs2),
        .EX_uses_FRs1(EX_uses_FRs1), .EX_uses_FRs2(EX_uses_FRs2),
        .MEMtoEX_forward(MEMtoEX_forward),               //01: Rs1=Rs2 / 10: Rs1 / 11: Rs2 / default : 00
        .WBtoEX_forward(WBtoEX_forward)       
    );   

    localparam NONE = 2'd0, FROM_MEM = 2'd1, FROM_WB = 2'd2;

    task clr;
        begin
            MEM_RegWrite = 0; WB_RegWrite = 0; MEM_FRegWrite = 0; WB_FRegWrite = 0; 
            EX_is_FPU = 0; EX_is_FLW = 0; EX_is_FSW = 0; MEM_Rd = 0; WB_Rd = 0; EX_Rs1 = 0; EX_Rs2 = 0; 
            EX_uses_Rs1 = 0; EX_uses_Rs2 = 0; EX_uses_FRs1 = 0; EX_uses_FRs2 = 0;

        end
    endtask

    function hit(input rw, input frw, input [4:0]rd, input [4:0] rs, input u, input fu);
        hit = (((rw && u && (rd != 5'd0)) || (frw && fu)) && (rd == rs));
    endfunction

    function [3:0]ref_model;        // {00(MEMtoEX_forward), 00(WBtoEX_forward)} -> 4bit
        reg [1:0]me, we, s1, s2;
        begin
            s1 = NONE;
            if(hit(MEM_RegWrite, MEM_FRegWrite, MEM_Rd, EX_Rs1, EX_uses_Rs1, EX_uses_FRs1))begin
                s1 = FROM_MEM;
            end
            else if(hit(WB_RegWrite, WB_FRegWrite, WB_Rd, EX_Rs1, EX_uses_Rs1, EX_uses_FRs1))begin
                s1 = FROM_WB;
            end

            s2 = NONE;
            if(hit(MEM_RegWrite, MEM_FRegWrite, MEM_Rd, EX_Rs2, EX_uses_Rs2, EX_uses_FRs2))begin
                s2 = FROM_MEM;
            end
            else if(hit(WB_RegWrite, WB_FRegWrite, WB_Rd, EX_Rs2, EX_uses_Rs2, EX_uses_FRs2))begin
                s2 = FROM_WB;
            end


            me = 2'd0;
            if((s1 == FROM_MEM) && (s2 == FROM_MEM))begin
                me = 2'b01;
            end
            else if(s1 == FROM_MEM) begin
                me = 2'b10;
            end
            else if(s2 == FROM_MEM)begin
                me = 2'b11;
            end

            we = 2'd0;
            if((s1 == FROM_WB) && (s2 == FROM_WB))begin
                we = 2'b01;
            end
            else if(s1 == FROM_WB) begin
                we = 2'b10;
            end
            else if(s2 == FROM_WB)begin
                we = 2'b11;
            end

            ref_model = {me,we};
        end
    endfunction

    reg [3:0]exp;
    integer PASS, FAIL, count;
    initial begin
        PASS = 0; FAIL = 0; count = 1;

        repeat(1000)begin
            clr;
            case({$random} % 4)
                0: /* 정수 */begin
                    EX_is_FPU = 0; EX_is_FLW = 0; EX_is_FSW = 0; EX_uses_FRs1 = 0; EX_uses_FRs2 = 0;
                    case({$random} % 3)
                        0: /*JAL*/begin
                            EX_uses_Rs1=0; EX_uses_Rs2=0;
                        end
                        1: /*addi/LW/JALR*/begin
                            EX_uses_Rs1=1; EX_uses_Rs2=0;
                        end
                        2: /*R-type/SW/branch*/begin
                            EX_uses_Rs1=1; EX_uses_Rs2=1;
                        end
                    endcase
                end
                1: /* FP산수 */begin
                    EX_is_FPU = 1; EX_is_FLW = 0; EX_is_FSW = 0; EX_uses_FRs1 = 1; EX_uses_FRs2 = 1; EX_uses_Rs1 = 0; EX_uses_Rs2 = 0; 
                end
                2: /* FLW */begin
                    EX_is_FPU = 0; EX_is_FLW = 1; EX_is_FSW = 0; EX_uses_FRs1 = 0; EX_uses_FRs2 = 0; EX_uses_Rs1 = 1; EX_uses_Rs2 = 0; 
                end
                3: /* FSW */begin
                    EX_is_FPU = 0; EX_is_FLW = 0; EX_is_FSW = 1; EX_uses_FRs1 = 0; EX_uses_FRs2 = 1; EX_uses_Rs1 = 1; EX_uses_Rs2 = 0; 
                end
            endcase

            case({$random} % 3)
                0:/*아무것도안함*/ begin
                    MEM_RegWrite = 0; MEM_FRegWrite = 0;
                end
                1:/*정수 사용*/ begin
                    MEM_RegWrite = 1; MEM_FRegWrite = 0;
                end
                2:/*FP사용*/ begin
                    MEM_RegWrite = 0; MEM_FRegWrite = 1;
                end
            endcase

            case({$random} % 3)
                0:/*아무것도안함*/ begin
                    WB_RegWrite = 0; WB_FRegWrite = 0;
                end
                1:/*정수 사용*/ begin
                    WB_RegWrite = 1; WB_FRegWrite = 0;
                end
                2:/*FP사용*/ begin
                    WB_RegWrite = 0; WB_FRegWrite = 1;
                end
            endcase

            MEM_Rd = {$random} % 4;
            WB_Rd  = {$random} % 4;
            EX_Rs1 = {$random} % 4;
            EX_Rs2 = {$random} % 4;
            #1;

            exp = ref_model(); 
            if({MEMtoEX_forward, WBtoEX_forward} !== exp)begin
                $display("[FAIL] / %0d, got %b, | expected %b || EX_Rs1: %b, EX_Rs2: %b | MEM_Rd: %b, WB_Rd: %b", count, {MEMtoEX_forward, WBtoEX_forward}, exp, EX_Rs1, EX_Rs2, MEM_Rd, WB_Rd);
                FAIL = FAIL + 1;
                count = count + 1;
            end
            else begin
                $display("[PASS] / %0d", count);
                PASS = PASS + 1;
                count = count + 1;
            end
        end
        $display("===== PASS=%0d FAIL=%0d =====", PASS, FAIL);
    $finish;
    end
endmodule