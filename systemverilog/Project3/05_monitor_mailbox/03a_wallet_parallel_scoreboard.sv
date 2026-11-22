interface wallet_if(input logic clk);
    logic reset;
    logic valid;
    logic [1:0]cmd;
    logic [7:0]amount;

    logic [7:0]balance;
    logic approved;

    clocking cb @(posedge clk);
        default input #1step output #0;

        output reset, valid, cmd, amount;
        input balance, approved;
    endclocking

    modport DUT_Wallet(
        input reset, valid, cmd, amount, clk,
        output balance, approved
    );

    modport monitor (
        input reset, valid, cmd, amount, clk, balance, approved
    );

    modport TB(
        clocking cb
    );
endinterface

module wallet(
    wallet_if.DUT_Wallet bus
);
    logic [7:0]balance;
    logic approved;
    
    wallet_logic u_wallet_logic(.bus(bus), .balance(balance), .approved(approved));

    always_ff @(posedge bus.clk or posedge bus.reset)begin
        if(bus.reset)begin
            bus.balance <= 0;
            bus.approved <= 0;
        end
        else begin
            bus.balance <= balance;
            bus.approved <= approved;
        end
    end
endmodule

module wallet_logic(
    wallet_if.DUT_Wallet bus,
    output logic [7:0]balance,
    output logic approved
);
    always_comb begin
        if(bus.reset)begin
            balance = 0;
            approved = 0;
        end
        else begin
            approved = 1'b0;
            balance = bus.balance;
            if(bus.valid)begin
                case(bus.cmd)
                    2'b00:begin
                        balance = bus.balance + bus.amount;
                        approved = 1'b1;
                    end

                    2'b01:begin
                        if(bus.balance >= bus.amount)begin
                            balance = bus.balance - bus.amount;
                            approved = 1'b1;
                        end
                        else begin
                            approved = 1'b0;
                        end
                    end

                    2'b10:begin
                        balance = bus.balance + (bus.amount * 2);
                        approved = 1'b1;
                    end

                    2'b11:begin
                        balance = 0;
                        approved = 1'b1;
                    end

                    default:;
                endcase
            end
        end
    end
endmodule

class Observation;
    logic [7:0]amount;
    logic [1:0]cmd;
    logic valid;
    logic reset;

    logic [7:0]actual_balance;
    logic actual_approved;
endclass


class Driver;
    virtual wallet_if.TB vir;
    rand bit[7:0]amount;
    rand bit[1:0]cmd;
    rand bit valid;

    constraint rand_value{
        amount inside{[8'd0 : 8'd50]};
        cmd dist {[2'b00  : 2'b10] :/ 9 , 2'b11 :/1};
        valid dist {1'b0 :/ 3, 1'b1 :/ 7};
    }

    function new(virtual wallet_if.TB vir);
        this.vir = vir;
    endfunction

    task run(input logic reset);
        begin
            if(this.randomize())begin
                vir.cb.amount <= amount;
                vir.cb.cmd <= cmd;
                vir.cb.valid <= valid;
                vir.cb.reset <= reset;
            end
            else begin
                $fatal(1,"ERROR");
            end
        end
    endtask

    task sat;
        begin
            vir.cb.amount <= 0;
            vir.cb.cmd <= 0;
            vir.cb.valid <= 0;
            vir.cb.reset <= 0;
        end
    endtask

endclass

class Monitor;
    virtual wallet_if.monitor vir;
    mailbox #(Observation)mb;

    function new(virtual wallet_if.monitor vir, mailbox #(Observation) mb);
        this.vir = vir;
        this.mb = mb;
    endfunction

    task run(output Observation obs);
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
    logic [7:0]balance;
    logic approved;
    logic [7:0]wallet;
    Observation obs;

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
                balance = 0;
                approved = 0;
                wallet = 0;
            end
            else begin
                approved = 1'b0;
                if(obs.valid)begin
                    case(obs.cmd)
                        2'b00:begin
                            balance = wallet + obs.amount;
                            approved = 1'b1;
                        end

                        2'b01:begin
                            if(wallet >= obs.amount)begin
                                balance = wallet - obs.amount;
                                approved = 1'b1;
                            end
                            else begin
                                approved = 1'b0;
                            end
                        end

                        2'b10:begin
                            balance = wallet + (obs.amount * 2);
                            approved = 1'b1;
                        end

                        2'b11:begin
                            balance = 0;
                            wallet = 0;
                            approved = 1'b1;
                        end

                        default:;
                    endcase
                end
                wallet = balance;
            end
        end
    endtask

    task check;
        begin
            count++;
            if(wallet === obs.actual_balance && approved === obs.actual_approved)begin
                PASS++;
            end
            else begin
                $display("%0d // actual balance: %0d | actual approved: %0d || expected balance: %0d | expected approved: %0d", count, obs.actual_balance, obs.actual_approved, wallet, approved);
                $display("amount: %0d | cmd: %b | valid: %0d | reset: %0d", obs.amount, obs.cmd, obs.valid, obs.reset);
                $fatal(1,"check ERROR");
            end
        end
    endtask
endclass

module Top;
    mailbox #(Observation)mb = new();

    logic clk = 1'b0;
    always #5 clk = ~clk;
    wallet_if bus(clk);
    wallet u_wallet(.bus(bus));

    Driver dri;
    Monitor mon;
    Scoreboard scr;

    Observation obs;

    initial begin
        dri = new(bus);
        mon = new(bus, mb);
        scr = new(mb);

        @(bus.cb);
        dri.run(1'b1);
        @(bus.cb);
        mon.run(obs);
        @(bus.cb);
        dri.sat();
        fork
            mon.push(obs);
            scr.predict();
            scr.check();
        join

        repeat(10)begin
            dri.run(1'b0);
            @(bus.cb);
            mon.run(obs);
            dri.sat();
            fork
                mon.push(obs);
                scr.predict();
            join
            scr.check();
        end
        scr.print();

        $finish;
    end
endmodule