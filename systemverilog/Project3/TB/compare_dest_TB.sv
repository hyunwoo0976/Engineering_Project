/*class Transaction;
    rand logic valid[0:2];
    logic checksum[0:2];
    rand logic [1:0]dest[0:2];
    rand logic [1:0]prio[0:2];
    rand logic [15:0]payload[0:2];
    rand logic [3:0]tag[0:2];

    constraint rand_trans{
        foreach(valid[i]){
            payload[i] inside{[16'd1 : 16'hFFFF]};
            dest[i] dist{[2'b00 : 2'b10] :/ 9 , 2'b11 :/ 1};
        }
        unique{tag};
    }

    function void post_randomize();
        foreach(valid[i]) {
            checksum[i] = ^{dest[i], prio[i], payload[i], tag[i]};
        }
    endfunction

    function void print();
        $display("=========================");
        $display("input port");
        $display("A: valid = %b, dest = %b, prio = %b, payload = %b, tag = %b", valid[0], dest[0], prio[0], payload[0], tag[0]);
        $display("B: valid = %b, dest = %b, prio = %b, payload = %b, tag = %b", valid[1], dest[1], prio[1], payload[1], tag[1]);
        $display("C: valid = %b, dest = %b, prio = %b, payload = %b, tag = %b", valid[2], dest[2], prio[2], payload[2], tag[2]);
        $display("=========================");
    endfunction
endclass

class Generator;
    Transaction handle;

    task gen;
        begin
            handle = new();
            if(handle.randomize() == 0)begin
                $fatal(1,"ERROR");
            end
            handle.print();
        end
    endtask
endclass

class Driver;
    virtual Router_if.TB vir;
    Transaction handle;
    mailbox #(Transaction) mb;


    function new(virtual DUT_Router.TB vir, mailbox #(Transaction) mb);
        this.vir = vir;
        this.mb = mb;
    endfunction

    task run;
        begin
            for(int i = 0; i<3; i++)begin
                vir.cb.valid[i] <= handle.valid[i];
                vir.cb.dest[i] <= handle.dest[i];
                vir.cb.prio[i] <= handle.prio[i];
                vir.cb.payload[i] <= handle.payload[i];
                vir.cb.tag[i] <= handle.tag[i];
            end
            @(vir.cb);
            mb.put(handle);
        end
    endtask
endclass

class Observation;
    logic valid[0:2];
    logic checksum[0:2];
    logic [1:0]dest[0:2];
    logic [1:0]prio[0:2];
    logic [15:0]payload[0:2];
    logic [3:0]tag[0:2];
    logic[24:0]out0, out1;
endclass

class Monitor;
    virtual Router_if.TB vir;
    Observation obs;

    function new(virtual DUT_Router.TB vir);
        this.vir = vir;
    endfunction

    task snap;
        begin
            for(int i = 0; i<3; i++)begin
                obs.valid[i] <= vir.cb.valid[i];
                obs.dest[i] <= vir.cb.dest[i];
                obs.prio[i] <= vir.cb.prio[i];
                obs.payload[i] <= vir.cb.payload[i];
                obs.tag[i] <= vir.cb.tag[i];
            end
            @(vir.cb);
            obs.out0 <= 
        end
    endtask
endclass

class Scoreboard;
    mailbox #(Transaction) mb;
    Transaction handle;
    logic valid[0:2];
    logic checksum[0:2];
    logic [1:0]dest[0:2];
    logic [1:0]prio[0:2];
    logic [15:0]payload[0:2];
    logic [3:0]tag[0:2];
    logic[24:0]out0, out1;

    function new(mailbox #(Transaction) mb);
        this.mb = mb;     
    endfunction

    task get;
        begin
            mb.get(handle);
            valid = handle.valid;
            checksum = handle.checksum;


        end
*/
`timescale 1ns/1ps
`include "../08_multiport_packet_router/Router_if.sv"
`include "../08_multiport_packet_router/compare_dest.sv"

class unpack;
    logic valid[0:2];
    logic checksum[0:2];
    logic [1:0]dest[0:2];
    logic [1:0]prio[0:2];
    logic [15:0]payload[0:2];
    logic [3:0]tag[0:2];
    
    task run(input logic [24:0]A, input logic [24:0]B, input logic [24:0]C);
        begin
            valid[0] = A[24];
            valid[1] = B[24];
            valid[2] = C[24];

            dest[0] = A[23:22];
            dest[1] = B[23:22];
            dest[2] = C[23:22];

            prio[0] = A[21:20];
            prio[1] = B[21:20];
            prio[2] = C[21:20];

            payload[0] = A[19 -: 16];
            payload[1] = B[19 -: 16];
            payload[2] = C[19 -: 16];

            tag[0] = A[3:0];
            tag[1] = B[3:0];
            tag[2] = C[3:0];

           checksum[0] = ^A[23:0];
           checksum[1] = ^B[23:0];
           checksum[2] = ^C[23:0];
        end
    endtask
endclass


class Driver;
    virtual Router_if.TB vir;
    unpack u;

    function new(virtual Router_if.TB vir);
        this.vir = vir;    
    endfunction

    task run(input logic [24:0]A, input logic [24:0]B, input logic [24:0]C);
        begin
            u = new();
            u.run(A, B, C);
            @(vir.cb);
            vir.cb.valid[0] <= u.valid[0];
            vir.cb.valid[1] <= u.valid[1];
            vir.cb.valid[2] <= u.valid[2];

            vir.cb.dest[0] <= u.dest[0];
            vir.cb.dest[1] <= u.dest[1];
            vir.cb.dest[2] <= u.dest[2];

            vir.cb.prio[0] <= u.prio[0];
            vir.cb.prio[1] <= u.prio[1];
            vir.cb.prio[2] <= u.prio[2];

            vir.cb.payload[0] <= u.payload[0];
            vir.cb.payload[1] <= u.payload[1];
            vir.cb.payload[2] <= u.payload[2];

            vir.cb.tag[0] <= u.tag[0];
            vir.cb.tag[1] <= u.tag[1];
            vir.cb.tag[2] <= u.tag[2];

            vir.cb.checksum[0] <= u.checksum[0];
            vir.cb.checksum[1] <= u.checksum[1];
            vir.cb.checksum[2] <= u.checksum[2];
            @(vir.cb);
        end
    endtask
endclass

class Scoreboard;
    virtual Router_if.TB vir;
    unpack u;
    logic [24:0] actual_out0;
    logic [24:0] actual_out1;

    logic checksum_out0;
    logic checksum_out1;

    logic[3:0]tag0;
    logic[3:0]tag1;

    logic pass0, pass1, FAIL0, FAIL1;

    int FAIL = 0;
    int PASS = 0;

    function new(virtual Router_if.TB vir);
        this.vir = vir;
    endfunction

    function void scr_print();
        $display("PASS: %0d || FAIL: %0d",PASS,FAIL);
    endfunction

    task actual(input logic[24:0]out0, input logic[24:0] out1);
        begin
            actual_out0 = out0;
            actual_out1 = out1;

            checksum_out0 = out0[0];
            checksum_out1 = out1[0];

            tag0 = out0[4:1];
            tag1 = out1[4:1];
        end
    endtask

    task check(input logic [24:0]expected_out0, input logic [24:0]expected_out1);
        logic calculated_checksum0;
        logic calculated_checksum1;

        begin
            pass0 = 1'b1; pass1 = 1'b1; FAIL0 = 1'b0; FAIL1 = 1'b0;
            calculated_checksum0 = ^actual_out0[24:1];
            calculated_checksum1 = ^actual_out1[24:1];

            if(checksum_out0 !== calculated_checksum0)begin
                pass0 = 1'b0;
                FAIL0 = 1'b1;
                $display("OUT0 CHECKSUM ERROR: received=%b, calculated=%b", checksum_out0, calculated_checksum0);
            end

            if(checksum_out1 !== calculated_checksum1)begin
                pass1 = 1'b0;
                FAIL1 = 1'b1;
                $display("OUT1 CHECKSUM ERROR: received=%b, calculated=%b", checksum_out1, calculated_checksum1);
            end

            if(expected_out0 !== actual_out0)begin
                pass0 = 1'b0;
                FAIL0 = 1'b1;
                $display("OUT0 MISMATCH: expected=%b, actual=%b", expected_out0, actual_out0);
            end

            if(expected_out1 !== actual_out1)begin
                pass1 = 1'b0;
                FAIL1 = 1'b1;
                $display("OUT1 MISMATCH: expected=%b, actual=%b", expected_out1, actual_out1);
            end

            if(pass0 && pass1)begin
                PASS++;
                $display("PASS");
            end
            else begin
                FAIL++;
                $display("FAIL");
            end

            @(vir.cb);
        end
    endtask
endclass

module Top;
    Driver dri;
    Scoreboard scr;

    logic[24:0]out0, out1;
    logic clk = 0;
    always #5 clk = ~clk;

    Router_if bus(clk);


    compare_dest u_compare_dest(.bus(bus), .out0(out0), .out1(out1));

    initial begin
        // 입력 25비트: {valid, dest, prio, payload, tag}
        // 출력 25비트: {dest, prio, payload, tag, checksum}

        dri = new(bus);
        scr = new(bus);
        // 1. A/B/C 모두 out0 경쟁
        // B의 priority가 가장 높음
        dri.run(25'h110064A, 25'h1000C8B, 25'h12012CC);
        scr.actual(out0, out1);
        scr.check(25'h0001916, 25'h0000000);


        // 2. A/B/C 모두 out1 경쟁
        // C의 priority가 가장 높음
        dri.run(25'h16006E1, 25'h1500DC2, 25'h14014A3);
        scr.actual(out0, out1);
        scr.check(25'h0000000, 25'h0802947);


        // 3. A/B가 out0 경쟁, C는 out1
        // out0=B, out1=C
        dri.run(25'h1200784, 25'h1100E65, 25'h1701546);
        scr.actual(out0, out1);
        scr.check(25'h0201CCA, 25'h0E02A8D);


        // 4. A는 out0, B/C는 out1 경쟁
        // out0=A, out1=C
        dri.run(25'h1300827, 25'h1600F08, 25'h14015E9);
        scr.actual(out0, out1);
        scr.check(25'h060104F, 25'h0802BD3);


        // 5. A만 valid=1
        // out0=A, out1=0
        dri.run(25'h12008CA, 25'h0000FAB, 25'h040168C);
        scr.actual(out0, out1);
        scr.check(25'h0401194, 25'h0000000);


        // 6. A/B/C 모두 valid=0
        // 출력 없음
        dri.run(25'h0000961, 25'h0401042, 25'h0801723);
        scr.actual(out0, out1);
        scr.check(25'h0000000, 25'h0000000);


        // 7. A는 dest=11이므로 제외
        // out0=B, out1=C
        dri.run(25'h1C00A04, 25'h11010E5, 25'h16017C6);
        scr.actual(out0, out1);
        scr.check(25'h02021CB, 25'h0C02F8C);


        // 8. A가 broadcast
        // out0=A, out1=A
        dri.run(25'h1900AA7, 25'h0001188, 25'h0401869);
        scr.actual(out0, out1);
        scr.check(25'h120154F, 25'h120154F);


        // 9. A는 broadcast, B는 out0
        // B의 priority가 더 높으므로 out0=B, out1=A
        dri.run(25'h1A00B4A, 25'h100122B, 25'h040190C);
        scr.actual(out0, out1);
        scr.check(25'h0002456, 25'h1401694);


        // 10. A는 broadcast, B는 out1
        // B의 priority가 더 높으므로 out0=A, out1=B
        dri.run(25'h1B00BE1, 25'h14012C2, 25'h00019A3);
        scr.actual(out0, out1);
        scr.check(25'h16017C2, 25'h0802584);

        scr.scr_print();
        $finish;
    end
endmodule
