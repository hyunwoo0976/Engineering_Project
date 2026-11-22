interface simple_if(input logic clk);
    logic reset;
    logic valid;
    logic sel;
    logic [7:0]data;
    logic [1:0]op;
    logic [7:0]result0;
    logic [7:0]result1;

    clocking cb @(posedge clk);
        default input #1step output #0;

        output reset, valid, sel, data, op;
        input result0, result1;
    endclocking

    modport DUT_dual_bank(
        input reset,valid,sel,data,op,clk,
        output result0,result1
    );

    modport TB(
        clocking cb
    );
endinterface

module dual_bank(simple_if.DUT_dual_bank bus);
    logic [7:0]reg0, reg1;

    reg0_next_logic u_reg0_next_logic(.bus(bus), .result0(reg0));
    reg1_next_logic u_reg1_next_logic(.bus(bus), .result1(reg1));

    always_ff @(posedge bus.clk or posedge bus.reset)begin
        if(bus.reset)begin
            bus.result0 <= 0;
            bus.result1 <= 0;
        end
        else if(bus.op == 2'b11 && bus.valid)begin
            bus.result0 <= reg1;
            bus.result1 <= reg0;
        end
        else begin
            bus.result0 <= reg0;
            bus.result1 <= reg1;
        end
    end
endmodule

module reg0_next_logic(
    simple_if.DUT_dual_bank bus,
    output logic[7:0]result0 
);

    always_comb begin
        result0 = bus.result0;
        if(bus.valid && !bus.sel)begin
            case(bus.op)
                2'b00:begin
                    result0 = bus.data;
                end

                2'b01:begin
                    result0 = bus.result0 + bus.data;
                end

                2'b10:begin
                    result0 = bus.result0 - bus.data;
                end
                default:;
            endcase
        end
    end
endmodule

module reg1_next_logic(
    simple_if.DUT_dual_bank bus,
    output logic[7:0]result1    
);
    always_comb begin
        result1 = bus.result1;
        if(bus.valid && bus.sel)begin
            case(bus.op)
                2'b00:begin
                    result1 = bus.data;
                end

                2'b01:begin
                    result1 = bus.result1 + bus.data;
                end

                2'b10:begin
                    result1 = bus.result1 - bus.data;
                end
                default:;
            endcase
        end
    end
endmodule

class Observation;
    logic [7:0] actual0;
    logic [7:0] actual1;
endclass

class Driver;
    virtual simple_if.TB vir;

    function new(virtual simple_if.TB vir);
        this.vir = vir;
    endfunction

    task run(input logic[7:0]data, input logic[1:0]op, input logic sel, input logic valid, input logic reset);
        begin
            vir.cb.data <= data;
            vir.cb.op <= op;
            vir.cb.sel <= sel;
            vir.cb.valid <= valid;
            vir.cb.reset <= reset;
        end
    endtask
endclass

class Monitor;
    virtual simple_if.TB vir;

    function new(virtual simple_if.TB vir);
        this.vir = vir;
    endfunction

    task sample(output Observation obs);
        obs = new();
        obs.actual0 = vir.cb.result0;
        obs.actual1 = vir.cb.result1;
    endtask
endclass

class Scoreboard;
    logic [7:0]expected0, expected1;
    logic [7:0]temp;
    int PASS = 0;

    function void print();
        $display("PASS: %0d", PASS);
    endfunction

    task check(input Observation obs);
        begin
            if(expected0 === obs.actual0 && expected1 === obs.actual1)begin
                PASS++;
            end
            else begin
                $display("result0: %0d | result1: %0d || expected0: %0d | expected1: %0d", obs.actual0, obs.actual1, expected0, expected1);
                $fatal(1, "ERROR");
            end
        end
    endtask
        

    task predict(input logic[7:0]data, input logic[1:0]op, input logic sel, input logic valid, input logic reset);
        begin
            if(reset)begin
                expected0 = 0;
                expected1 = 0;
            end
            else begin
                if(valid)begin
                    if(!sel)begin
                        case(op)
                            2'b00:begin
                                expected0 = data;
                            end

                            2'b01: begin
                                expected0 = expected0 + data;
                            end

                            2'b10:begin
                                expected0 = expected0 - data;
                            end

                            2'b11:begin
                                temp = expected0;
                                expected0 = expected1;
                                expected1 = temp;
                            end
                        endcase
                    end
                    else begin
                        case(op)
                            2'b00:begin
                                expected1 = data;
                            end

                            2'b01: begin
                                expected1 = expected1 + data;
                            end

                            2'b10:begin
                                expected1 = expected1 - data;
                            end

                            2'b11:begin
                                temp = expected1;
                                expected1 = expected0;
                                expected0 = temp;
                            end
                        endcase
                    end
                end
            end
        end
    endtask

endclass

module Top;
    logic clk = 1'b0;

    always #5 clk = ~clk;

    simple_if bus(clk);
    dual_bank u_dual_bank(.bus(bus));

    Driver dri;
    Scoreboard scr;
    Monitor mon;

    Observation obs;

    initial begin
        dri = new(bus);
        mon = new(bus);
        scr = new();

        @(bus.cb);
        dri.run    (8'd0, 2'b00, 1'b0, 1'b0, 1'b1);
        scr.predict(8'd0, 2'b00, 1'b0, 1'b0, 1'b1);
        @(bus.cb);@(bus.cb);
        mon.sample(obs);
        scr.check(obs);

        dri.run    (8'd20, 2'b00, 1'b0, 1'b1, 1'b0);
        scr.predict(8'd20, 2'b00, 1'b0, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        mon.sample(obs);
        scr.check(obs);

        // 3. result1에 7 LOAD
        dri.run    (8'd7, 2'b00, 1'b1, 1'b1, 1'b0);
        scr.predict(8'd7, 2'b00, 1'b1, 1'b1, 1'b0);

        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);

        @(bus.cb);
        mon.sample(obs);
        scr.check(obs);

        scr.print();

        $finish;
    end
endmodule