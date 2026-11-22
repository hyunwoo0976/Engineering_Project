interface cal_if(input logic clk);
    logic reset;
    logic valid;
    logic [1:0]cmd;
    logic [7:0]data;

    logic [7:0]result;
    logic result_valid;

    clocking cb @(posedge clk);
        default input #1step output #0;
        output reset, valid, cmd, data;
        input result, result_valid;
    endclocking

    modport DUT_calculator(
        input reset, valid, cmd, data, clk,
        output result, result_valid
    );

    modport TB(
        clocking cb
    );
    
endinterface //cal_if

module calculator (
    cal_if.DUT_calculator bus
);

    always_ff @(posedge bus.clk or posedge bus.reset ) begin
        if(bus.reset)begin
            bus.result <= 0;
            bus.result_valid <= 0;
        end
        else begin

            if(bus.valid)begin
                bus.result_valid <= 1;
                case(bus.cmd)
                    2'b00:begin
                        bus.result <= bus.data;
                    end

                    2'b01:begin
                        bus.result <= bus.result + bus.data;
                    end

                    2'b10:begin
                        bus.result <= bus.result ^ bus.data;
                    end

                    default:;
                endcase
            end
            else begin
                bus.result_valid <= 0;
            end
        end
    end
endmodule

class Transaction;
    rand bit [7:0] data;
    rand bit [1:0] cmd;

    constraint rand_trans{
        data inside{[7'd0 : 7'd50]};
        cmd dist {2'b00 :/ 3, 2'b01 :/ 4, 2'b10 :/ 2, 2'b11 :/ 1};
    }

    function void print;
        $display("[TR] data = %0d, cmd = %b",data,cmd);
    endfunction
endclass

class Observation;
    bit [7:0]actual_result;
endclass

class Generator;
    mailbox #(Transaction) gen2drv;
    Transaction trn;

    function new(mailbox #(Transaction) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run(int count);
        begin
            repeat (count)begin
                trn = new();
                if(!trn.randomize())begin
                    $fatal(1,"ERROR");
                end
                gen2drv.put(trn);
                trn.print();
            end
        end
    endtask
endclass

class Driver;
    virtual cal_if.TB vir;
    mailbox #(Transaction) gen2drv;
    mailbox #(Transaction) drv2scr;
    Transaction trn;

    function new(virtual cal_if.TB vir, mailbox #(Transaction) gen2drv, mailbox #(Transaction) drv2scr);
        this.vir = vir;
        this.gen2drv = gen2drv;
        this.drv2scr = drv2scr;
    endfunction

    task reset_dut;
        begin
            vir.cb.reset <= 1;
            vir.cb.valid <= 0;
            vir.cb.cmd <= 0;
            vir.cb.data <= 0;
            @(vir.cb);
            @(vir.cb);
            vir.cb.reset <= 0;
            @(vir.cb);
        end
    endtask

    task run(int count);
        begin
            repeat(count)begin
                gen2drv.get(trn);
                @(vir.cb);
                vir.cb.valid <= 1;
                vir.cb.cmd <= trn.cmd;
                vir.cb.data <= trn.data;
                trn.print();
                drv2scr.put(trn);
                @(vir.cb);
                vir.cb.valid <= 0;
            end
        end
    endtask
endclass

class Monitor;
    virtual cal_if.TB vir;
    mailbox #(Observation) mon2scr;
    Observation obs;

    function new(virtual cal_if.TB vir, mailbox #(Observation) mon2scr);
        this.mon2scr = mon2scr;
        this.vir = vir;
    endfunction

    task run(int count);
        int received;

        begin
            received = 0;
            while(received < count)begin
                @(vir.cb);
                if(vir.cb.result_valid == 1)begin
                    obs = new();
                    obs.actual_result = vir.cb.result;
                    mon2scr.put(obs);

                    received++;
                end
            end
        end
    endtask
endclass

class Scoreboard;
    mailbox #(Transaction) drv2scr;
    mailbox #(Observation) mon2scr;
    Transaction trn;
    Observation obs;
    int PASS = 0;

    bit [7:0] expected_result;

    function new(mailbox #(Transaction) drv2scr, mailbox #(Observation) mon2scr);
        this.drv2scr = drv2scr;
        this.mon2scr = mon2scr;
    endfunction

    task run(int count);
        begin
            repeat(count)begin
                drv2scr.get(trn);
                mon2scr.get(obs);
                case(trn.cmd)
                    2'b00: expected_result = trn.data;
                    2'b01: expected_result = expected_result + trn.data;
                    2'b10: expected_result = expected_result ^ trn.data;
                    2'b11: expected_result = expected_result;
                endcase

                if(expected_result !== obs.actual_result)begin
                    $fatal(1,
                        "[FAIL] %0d || expected=%0d, actual=%0d",
                        PASS,expected_result,
                        obs.actual_result
                    );
                end
                else begin
                    PASS++;
                end
            end
            $display("[PASS %0d] expected=%0d, actual=%0d", PASS, expected_result, obs.actual_result);
        end
    endtask
endclass

module Top;
    logic clk = 0;
    always #5 clk = ~clk;
    cal_if bus(clk);
    calculator u_calculator(.bus(bus));
    mailbox #(Transaction) gen2drv = new();
    mailbox #(Transaction) drv2scr = new();
    mailbox #(Observation) mon2scr = new();

    Generator gen = new(gen2drv);
    Driver dri = new(bus, gen2drv, drv2scr);
    Monitor mon = new(bus, mon2scr);
    Scoreboard scr = new(drv2scr, mon2scr);

    initial begin
        dri.reset_dut();
        fork
            gen.run(20);
            dri.run(20);
            mon.run(20);
            scr.run(20);
        join

        #5000;
        $finish;
        
    end
endmodule
