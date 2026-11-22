interface wallet_if(input logic clk);
    logic reset;
    logic valid;
    logic [1:0]cmd;
    logic [7:0]amount;

    logic[7:0]balance;
    logic approved;

    clocking cb @(posedge clk);
        default input #1step output #0;

        output reset,valid,cmd,amount;
        input balance,approved;
    endclocking

    modport DUT_Wallet(
        input reset, valid, cmd, amount, clk,
        output balance, approved
    );

    modport Monitor(
        input reset,valid,cmd,amount,balance,approved
    );

    modport TB(
        clocking cb
    );
endinterface

module Wallet(
    wallet_if.DUT_Wallet bus
);  
    logic [7:0]current_money;
    logic approved;

    Wallet_logic u_Wallet_logic(.bus(bus), .current_money(current_money), .approved(approved));
    
    always_ff @(posedge bus.clk or posedge bus.reset)begin
        if(bus.reset)begin
            bus.balance <= 0;
            bus.approved <= 0;
        end
        else begin
            bus.balance <= current_money;
            bus.approved <= approved;
        end
    end
endmodule

module Wallet_logic(
    wallet_if.DUT_Wallet bus,
    output logic [7:0]current_money,
    output logic approved
);
    always_comb begin
        current_money = bus.balance;
        approved = bus.approved;
        if(bus.reset)begin
            approved = 1'b0;
        end
        if(bus.valid)begin
            case(bus.cmd)
                2'b00: begin
                    current_money = bus.balance + bus.amount;
                    approved = 1'b1;
                end

                2'b01: begin
                    if(bus.balance >= bus.amount)begin
                        current_money = bus.balance - bus.amount;
                        approved = 1'b1;
                    end
                    else begin
                        approved = 1'b0;
                    end
                end

                2'b10: begin
                    current_money = bus.balance + (bus.amount * 2);
                    approved = 1'b1;
                end

                2'b11: begin
                    current_money = 0;
                    approved = 1'b1;
                end
            endcase
        end
    end
endmodule
        

class Observation;
    logic reset;
    logic valid;
    logic [1:0]cmd;
    logic [7:0]amount;
    
    logic [7:0]actual_balance;
    logic actual_approved;
endclass

class Driver;
    virtual wallet_if.TB vir;

    function new(virtual wallet_if.TB vir);
        this.vir = vir;
    endfunction

    task run(input logic[7:0]amount, input logic[1:0]cmd, input logic valid, input logic reset);
        begin
            vir.cb.amount <= amount;
            vir.cb.cmd <= cmd;
            vir.cb.valid <= valid;
            vir.cb.reset <= reset;
        end
    endtask
endclass


class Monitor;
    virtual wallet_if.Monitor vir;

    mailbox #(Observation) mb;

    function new(virtual wallet_if.Monitor vir, mailbox #(Observation)mb);
        this.vir = vir;
        this.mb = mb;
    endfunction

    task sample_in(output Observation obs);
        begin
            obs = new();
            obs.amount = vir.amount;
            obs.cmd = vir.cmd;
            obs.valid = vir.valid;
            obs.reset = vir.reset;
        end
    endtask

    task push(Observation obs);
        begin
            obs.actual_approved = vir.approved;
            obs.actual_balance = vir.balance;
            mb.put(obs);
        end
    endtask

endclass

class Scoreboard;
    mailbox #(Observation)mb;
    Observation obs;
    logic[7:0] current_money;
    logic [7:0]wallet;
    logic approved;

    int PASS = 0;
    int count = 0;

    function new(mailbox #(Observation)mb);
        this.mb = mb;
    endfunction

    function void print();
        $display("PASS: %0d", PASS);
    endfunction

    task predict;
        begin
            mb.get(obs);
            if(obs.reset)begin
                wallet = 8'd0;
                current_money = 8'd0;
                approved = 1'b0;
            end
            else begin
                if(obs.valid)begin
                    case(obs.cmd)
                        2'b00: begin
                            current_money = wallet + obs.amount;
                            approved = 1'b1;
                        end

                        2'b01: begin
                            if(wallet >= obs.amount)begin
                                current_money = wallet - obs.amount;
                                approved = 1'b1;
                            end
                            else begin
                                approved = 1'b0;
                            end
                        end

                        2'b10: begin
                            current_money = wallet + (obs.amount * 2);
                            approved = 1'b1;
                        end

                        2'b11: begin
                            current_money = 0;
                            approved = 1'b1;
                        end
                    endcase
                end
            end
            wallet = current_money;
        end
    endtask

    task check;
        begin
            count++;
            if(obs.actual_balance === current_money && obs.actual_approved === approved)begin
                PASS++;
            end
            else begin
                $display("%0d: balance: %0d | approved: %0d || expected balance: %0d, expected approved: %0d", count, obs.actual_balance, obs.actual_approved, current_money,approved);
                $fatal(1,"ERROR");
            end
        end
    endtask
endclass

module Top;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    wallet_if bus(clk);
    Wallet u_Wallet(.bus(bus));

    mailbox #(Observation) mb = new();

    Driver dri;
    Monitor mon;
    Scoreboard scr;

    Observation obs;

    initial begin
        dri = new(bus);
        mon = new(bus, mb);
        scr = new(mb);

        //1 : 리셋
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b1);
        @(bus.cb);
        mon.sample_in(obs);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        mon.push(obs);
        scr.predict();
        scr.check();

        //2 : 50충전
        dri.run(8'd50, 2'b00, 1'b1, 1'b0);
        @(bus.cb);
        mon.sample_in(obs);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        mon.push(obs);
        scr.predict();
        scr.check();

        //3 : 20결제
        dri.run(8'd20, 2'b01, 1'b1, 1'b0);
        @(bus.cb);
        mon.sample_in(obs);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        mon.push(obs);
        scr.predict();
        scr.check();

        //4 : 40결제시도
        dri.run(8'd40, 2'b01, 1'b1, 1'b0);
        @(bus.cb);
        mon.sample_in(obs);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        mon.push(obs);
        scr.predict();
        scr.check();

        //5 : 5보너스
        dri.run(8'd5, 2'b10, 1'b1, 1'b0);
        @(bus.cb);
        mon.sample_in(obs);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        mon.push(obs);
        scr.predict();
        scr.check();

        //6 : 잔액삭제
        dri.run(8'd03, 2'b11, 1'b1, 1'b0);
        @(bus.cb);
        mon.sample_in(obs);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        mon.push(obs);
        scr.predict();
        scr.check();

        scr.print();
        $finish;
    end
endmodule




