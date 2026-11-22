interface simple_if(input logic clk);
    logic reset;
    logic valid;
    logic sel;      //sel 0 -> acc0 / sel 1 -> acc1
    logic [7:0]data;
    logic [1:0]op;
    logic [7:0]result0;
    logic [7:0]result1;

    clocking cb @(posedge clk);
        default input #1step output #0;

        output reset, valid, sel, data, op;
        input result0, result1;
    endclocking

    modport DUT_acc(
        input reset, valid, sel, data, op, clk,
        output result0, result1
    );

    modport TB(
        clocking cb
    );
endinterface

module acc(simple_if.DUT_acc bus);
    logic [7:0]tmp_result0, tmp_result1;

    acc0 u_acc0(.bus(bus), .result0(tmp_result0));
    acc1 u_acc1(.bus(bus), .result1(tmp_result1));

    always_ff @( posedge bus.clk or posedge bus.reset ) begin
        if(bus.reset)begin
            bus.result0 <= 8'b0;
            bus.result1 <= 8'b0;
        end
        else begin
            bus.result0 <= tmp_result0;
            bus.result1 <= tmp_result1;
        end
    end
    
endmodule

module acc0(
    simple_if.DUT_acc bus,
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

                2'b11:begin
                    result0 = bus.result0 ^ bus.data;
                end
                default:;
            endcase
        end
    end
endmodule

module acc1(
    simple_if.DUT_acc bus,
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

                2'b11:begin
                    result1 = bus.result1 ^ bus.data;
                end
                default:;
            endcase
        end
    end
endmodule

class Driver;
    virtual simple_if.TB vir;

    function new(virtual simple_if.TB vir);
        this.vir = vir;
    endfunction

    task run(input logic[7:0] data, input logic[1:0]op, input logic valid, input logic sel, input logic reset);
        begin
            vir.cb.data <= data;
            vir.cb.op <= op;
            vir.cb.valid <= valid;
            vir.cb.sel <= sel;
            vir.cb.reset <= reset;
        end
    endtask
endclass

class Scoreboard;
    virtual simple_if.TB vir;
    int PASS = 0;

    function new(virtual simple_if.TB vir);
        this.vir = vir;
    endfunction

    function void print();
        $display("PASS: %0d", PASS);
    endfunction

    task check(input logic[7:0]expected0, input logic[7:0]expected1);
        begin
            if(expected0 === vir.cb.result0 && expected1 === vir.cb.result1)begin
                PASS++;
            end
            else begin
                $display("ERROR!! || result0: %b | result1: %b || expected0: %b | expected1: %b", vir.cb.result0, vir.cb.result1, expected0, expected1);
                $fatal(1,"ERROR");
            end
        end
    endtask
endclass

module Top;
    logic clk = 1'b0;

    always #5 clk = ~clk;
    simple_if bus(clk);
    
    Driver dri;
    Scoreboard scr;
    acc u_acc(.bus(bus));

    initial begin
        dri = new(bus);
        scr = new(bus);

        @(bus.cb);
        // 1. reset
        dri.run(8'd99, 2'b00, 1'b0, 1'b0, 1'b1);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check(8'd0, 8'd0);

        // 2. acc0 LOAD 10
        dri.run(8'd10, 2'b00, 1'b1, 1'b0, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check(8'd10, 8'd0);

        // 3. acc1 LOAD 50
        dri.run(8'd50, 2'b00, 1'b1, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check(8'd10, 8'd50);

        // 4. acc0 ADD 5
        dri.run(8'd5, 2'b01, 1'b1, 1'b0, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check(8'd15, 8'd50);

        // 5. acc1 SUB 7
        dri.run(8'd7, 2'b10, 1'b1, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check(8'd15, 8'd43);

        // 6. valid=0: 둘 다 유지
        dri.run(8'd100, 2'b01, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check(8'd15, 8'd43);

        // 7. acc0 ADD 250: 8비트 overflow
        dri.run(8'd250, 2'b01, 1'b1, 1'b0, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check(8'd9, 8'd43);

        // 8. acc1 XOR 3
        dri.run(8'd3, 2'b11, 1'b1, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check(8'd9, 8'd40);

        // 9. reset과 valid 동시 1: reset 우선
        dri.run(8'd200, 2'b01, 1'b1, 1'b1, 1'b1);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check(8'd0, 8'd0);

        scr.print();
        $finish;
    end
endmodule