`timescale 1ns/1ps
`include "../08_multiport_packet_router/Router_if.sv"
`include "../08_multiport_packet_router/compare_dest.sv"
`include "../08_multiport_packet_router/detailed_Router.sv"
`include "../08_multiport_packet_router/FIFOQ.sv"
`include "../08_multiport_packet_router/Router.sv"
class Transaction;
    rand logic valid[0:2];
    logic checksum[0:2];
    rand logic [1:0]dest[0:2];
    rand logic [1:0] prio[0:2];
    rand bit [15:0]payload[0:2];
    rand logic [3:0]tag[0:2];

    constraint rand_trans{
        foreach(valid[i]){
            dest[i] dist{[2'b00 : 2'b10] :/ 9 , 2'b11 :/ 1};
        }
        foreach(payload[i]){
            payload[i] inside{[16'd1 : 16'hFFFF]};
        }
        tag[0] != tag[1];
        tag[0] != tag[2];
        tag[1] != tag[2];
    }

    function void post_randomize();
        foreach(valid[i])begin
            checksum[i] = ^{dest[i], prio[i], payload[i], tag[i]};
        end
    endfunction

    function void print();
        $display("A: %b_%b_%b_%b_%b", valid[0], dest[0], prio[0], payload[0], tag[0]);
        $display("B: %b_%b_%b_%b_%b", valid[1], dest[1], prio[1], payload[1], tag[1]);
        $display("C: %b_%b_%b_%b_%b", valid[2], dest[2], prio[2], payload[2], tag[2]);
    endfunction
endclass

class Observation;
    logic out_valid [0:1], out_checksum [0:1];
    logic [1:0]out_dest [0:1], out_prio [0:1];
    logic [15:0]out_payload [0:1];
    logic [3:0]out_tag [0:1];
endclass


class Generator;
    Transaction handle;
    mailbox #(Transaction)gen2dri;
    
    function new(mailbox #(Transaction)gen2dri);
        this.gen2dri = gen2dri;
    endfunction

    task run;
        begin
            handle = new();
            if(handle.randomize() == 0)begin
                handle.print();
                $fatal(1,"ERROR");
            end
            gen2dri.put(handle);
        end
    endtask
endclass


class Driver;
    virtual Router_if.TB vir;
    mailbox #(Transaction)gen2dri;
    mailbox #(Transaction) dri2scr;
    Transaction handle;

    function new(virtual Router_if.TB vir, mailbox #(Transaction)gen2dri, mailbox #(Transaction) dri2scr);
        this.vir = vir;
        this.gen2dri = gen2dri;
        this.dri2scr = dri2scr;
    endfunction

    task run;
        begin
            gen2dri.get(handle);
            for(int i=0; i<3 ; i++)begin
                vir.cb.valid[i] <= handle.valid[i];
                vir.cb.checksum[i] <= handle.checksum[i];
                vir.cb.dest[i] <= handle.dest[i];
                vir.cb.prio[i] <= handle.prio[i];
                vir.cb.payload[i] <= handle.payload[i];
                vir.cb.tag[i] <= handle.tag[i];
            end
            dri2scr.put(handle);
            @(vir.cb);
            for (int i=0; i<3; i++) vir.cb.valid[i] <= 0;
        end
    endtask
endclass

class Monitor;
    virtual Router_if.TB vir;
    Observation obs;
    mailbox #(Observation)mon2scr;

    function new(virtual Router_if.TB vir, mailbox #(Observation)mon2scr);
        this.vir = vir;
        this.mon2scr = mon2scr;
    endfunction

    task run;
        begin
            obs = new();
            @(vir.cb); @(vir.cb);
            for(int i=0; i<2; i++)begin
                obs.out_valid[i] = vir.cb.out_valid[i];
                obs.out_checksum [i] = vir.cb.out_checksum[i];
                obs.out_dest [i] = vir.cb.out_dest[i];
                obs.out_prio [i] = vir.cb.out_prio[i];
                obs.out_payload [i] = vir.cb.out_payload[i];
                obs.out_tag [i] = vir.cb.out_tag[i];
            end
            mon2scr.put(obs);
        end
    endtask
endclass

class Scoreboard;
    Observation obs;
    Transaction handle;
    mailbox #(Transaction)dri2scr;
    mailbox #(Observation)mon2scr;

    logic [25:0]value[0:2]; // valid(1), checksum(1), dest(2), prio(2), payload(16), tag(4)
    logic a0, a1, b0, b1, c0, c1;
    logic [24:0] out0, out1;
    logic PASS0, PASS1;
    int PASS = 0;
    logic empty[0:2];
    logic [25:0]last_value[0:2];

    function new(mailbox #(Transaction)dri2scr, mailbox #(Observation)mon2scr);
        this.dri2scr = dri2scr;
        this.mon2scr = mon2scr;
        foreach (empty[i]) begin
            empty[i] = 1'b1;
            last_value[i] = '0;
            value[i] = '0;
        end
    endfunction

    function void PASS_print();
        $display("PASS: %0d", PASS);
    endfunction


    task run;
        begin
            dri2scr.get(handle);
            {a0, a1, b0, b1, c0, c1} = 6'b0;
            for(int i=0; i<3; i++)begin
                if(empty[i])begin
                   value[i] = {handle.valid[i], handle.dest[i], handle.prio[i], handle.payload[i], handle.tag[i], handle.checksum[i]}; 
                end
                else begin
                    value[i] = last_value[i];
                    last_value[i] = '0;
                end
                
                if(handle.valid[i])begin
                    case(handle.dest[i])
                        2'b00:begin
                            case(i)
                                0: a0 = 1;
                                1: b0 = 1;
                                2: c0 = 1;
                            endcase
                        end

                        2'b01:begin
                            case(i)
                                0: a1 = 1;
                                1: b1 = 1;
                                2: c1 = 1;
                            endcase
                        end

                        2'b10:begin
                            case(i)
                                0: {a0, a1} = 2'b11;
                                1: {b0, b1} = 2'b11;
                                2: {c0, c1} = 2'b11;
                            endcase
                        end
                    endcase
                end
                else begin
                    value[i] = '0;
                end
            end

            case(1'b1)
                (a0 && b0 && c0): begin
                    if(handle.prio[0] <= handle.prio[1])begin
                        if(handle.prio[0] <= handle.prio[2])begin
                            b0 = 0; c0 = 0;
                        end
                        else begin
                            a0 = 0; b0 = 0;
                        end
                    end
                    else begin
                        if(handle.prio[1] <= handle.prio[2])begin
                            a0 = 0; c0 = 0;
                        end
                        else begin
                            a0 = 0; b0 = 0;
                        end
                    end
                end

                (a0 && b0 && !c0): begin
                    if(handle.prio[0] <= handle.prio[1])begin
                        b0 = 0;
                    end
                    else begin
                        a0 = 0;
                    end
                end

                (a0 && c0 && !b0): begin
                    if(handle.prio[0] <= handle.prio[2])begin
                        c0 = 0;
                    end
                    else begin
                        a0 = 0;
                    end
                end

                (b0 && c0 && !a0): begin
                    if(handle.prio[1] <= handle.prio[2])begin
                        c0 = 0;
                    end
                    else begin
                        b0 = 0;
                    end
                end
            endcase

            case(1'b1)
                (a1 && b1 && c1): begin
                    if(handle.prio[0] <= handle.prio[1])begin
                        if(handle.prio[0] <= handle.prio[2])begin
                            b1 = 0; c1 = 0;
                        end
                        else begin
                            a1 = 0; b1 = 0;
                        end
                    end
                    else begin
                        if(handle.prio[1] <= handle.prio[2])begin
                            a1 = 0; c1 = 0;
                        end
                        else begin
                            a1 = 0; b1 = 0;
                        end
                    end
                end

                (a1 && b1 && !c1): begin
                    if(handle.prio[0] <= handle.prio[1])begin
                        b1 = 0;
                    end
                    else begin
                        a1 = 0;
                    end
                end

                (a1 && c1 && !b1): begin
                    if(handle.prio[0] <= handle.prio[2])begin
                        c1 = 0;
                    end
                    else begin
                        a1 = 0;
                    end
                end

                (b1 && c1 && !a1): begin
                    if(handle.prio[1] <= handle.prio[2])begin
                        c1 = 0;
                    end
                    else begin
                        b1 = 0;
                    end
                end
            endcase
            empty[0] = (a0 || a1) ? 1'b1 : 1'b0;
            empty[1] = (b0 || b1) ? 1'b1 : 1'b0;
            empty[2] = (c0 || c1) ? 1'b1 : 1'b0;

            

            for(int j=0; j<3; j++)begin
                last_value[j] = (empty[j] == 0) ? value[j] : '0;
            end

            out0 = (a0 == 1) ? value[0][24:0] : (b0 == 1) ? value[1][24:0] : (c0 == 1) ? value[2][24:0] : '0;
            out1 = (a1 == 1) ? value[0][24:0] : (b1 == 1) ? value[1][24:0] : (c1 == 1) ? value[2][24:0] : '0;
        end
    endtask

    task compare;
        begin
            mon2scr.get(obs);
            if(out0 === {obs.out_dest[0], obs.out_prio[0], obs.out_payload[0], obs.out_tag[0], obs.out_checksum[0]})begin
                PASS0 = 1'b1;
            end
            else begin
                $display("out0 => actual: %b || expect: %b",{obs.out_dest[0], obs.out_prio[0], obs.out_payload[0], obs.out_tag[0], obs.out_checksum[0]}, out0);
                $fatal(1,"ERROR");
            end

            if(out1 === {obs.out_dest[1], obs.out_prio[1], obs.out_payload[1], obs.out_tag[1], obs.out_checksum[1]})begin
                PASS1 = 1'b1;
            end
            else begin
                $display("out1 => actual: %b || expect: %b",{obs.out_dest[1], obs.out_prio[1], obs.out_payload[1], obs.out_tag[1], obs.out_checksum[1]}, out1);
                $fatal(1,"ERROR");
            end

            if(PASS0 || PASS1)begin
                PASS++;
            end
        end
    endtask

endclass

module Top;
    Generator gen;
    Driver dri;
    Monitor mon;
    Scoreboard scr;

    mailbox #(Transaction)gen2dri = new();
    mailbox #(Transaction)dri2scr = new();
    mailbox #(Observation)mon2scr = new();

    logic clk = 0;

    always #5 clk = ~clk;
    Router_if bus(clk);
    Router u_Router (.bus(bus));

    initial begin
        gen = new(gen2dri);
        dri = new(bus, gen2dri, dri2scr);
        mon = new(bus, mon2scr);
        scr = new(dri2scr, mon2scr);

        bus.cb.reset <= 1;          // ← 리셋 펄스
        bus.cb.out_ready[0] <= 1;
        bus.cb.out_ready[1] <= 1;
        for (int i=0; i<3; i++) bus.cb.valid[i] <= 0;
        @(bus.cb); @(bus.cb);
        bus.cb.reset <= 0;
        @(bus.cb);


        repeat(20)begin
            gen.run();
            dri.run();
            mon.run();
            scr.run();
            scr.compare();
        end
        scr.PASS_print();
        $finish;
    end
endmodule



