interface alu_if(input logic clk);
    logic [7:0]a,b;
    logic[1:0]op;
    logic valid;
    logic [8:0]result;

    clocking cb @(posedge clk);
        default input #1step output #0;
        output a,b,op,valid;
        input result;
    endclocking

    modport DUT_alu(
        input a,b,op,valid,clk,
        output result
    );

    modport TB(
        clocking cb
    );
endinterface

module ALU(alu_if.DUT_alu bus);
    logic mont;

    assign mont = (bus.a >= bus.b) ? 1'b1 : 1'b0;

    always_ff @(posedge bus.clk)begin
        if(bus.valid)begin
            case(bus.op)
                2'b00:begin
                    bus.result <= bus.a + bus.b;
                end
                2'b01:begin
                    if(mont)begin
                        bus.result <= bus.a - bus.b;
                    end
                    else begin
                        bus.result <= bus.b - bus.a;
                    end
                end
                2'b10:begin
                    bus.result <= bus.a & bus.b;
                end
                2'b11:begin
                    bus.result <= bus.a | bus.b;
                end
                default;
            endcase
        end
    end
endmodule


class Driver;
    virtual alu_if.TB vir;

    function new(virtual alu_if.TB vir);
        this.vir = vir;
    endfunction

    task run(input logic[7:0] a, input logic[7:0] b, input logic[1:0] op, input logic valid);
        begin
            vir.cb.a <= a;
            vir.cb.b <= b;
            vir.cb.op <= op;
            vir.cb.valid <= valid;
        end
    endtask
endclass

class Scoreboard;
    virtual alu_if.TB vir;
    int PASS = 0;

    function new(virtual alu_if.TB vir);
        this.vir = vir;
    endfunction

    function void print();
        $display("PASS : %0d", PASS);
    endfunction

    task check(input logic[8:0] expected);
        begin
            if(vir.cb.result === expected)begin
                PASS++;
                $display("expected: %0d | result: %0d", expected,vir.cb.result);
            end
            else begin
                $fatal(1,"ERROR ! || result:%0d | expected: %0d", vir.cb.result, expected);
            end
        end
    endtask
endclass

module Top;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    alu_if bus(clk);

    ALU u_ALU(.bus(bus));

    Driver dri;
    Scoreboard scr;

    initial begin
        dri = new(bus);
        scr = new(bus);

        @(bus.cb);
        dri.run(8'd10, 8'd20, 2'b00, 1'b1);
        @(bus.cb);@(bus.cb);
        scr.check(9'd30);

        @(bus.cb);
        dri.run(8'd10, 8'd30, 2'b01, 1'b1);
        @(bus.cb);@(bus.cb);
        scr.check(9'd20);

        @(bus.cb);
        dri.run(8'd20, 8'd10, 2'b10, 1'b0);
        @(bus.cb);@(bus.cb);
        scr.check(9'd20);

        @(bus.cb);
        dri.run(8'd5, 8'd20, 2'b11, 1'b1);
        @(bus.cb);@(bus.cb);
        scr.check(8'd21);

        @(bus.cb);
        dri.run(8'd5, 8'd20, 2'b10, 1'b1);
        @(bus.cb);@(bus.cb);
        scr.check(8'd4);

        scr.print();
        
        $finish;
    end
endmodule