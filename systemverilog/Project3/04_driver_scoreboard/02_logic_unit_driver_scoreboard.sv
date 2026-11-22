interface logic_if(input logic clk);
    logic[7:0]a,b;
    logic[1:0] op;
    logic[9:0]result;
    logic valid;

    clocking cb @(posedge clk);
        default input #1step output #0;

        output a,b,op,valid;
        input result;
    endclocking

    modport DUT_logicunit(
        input a,b,op,clk,valid,
        output result
    );

    modport TB(
        clocking cb
    );
endinterface

module logicunit(logic_if.DUT_logicunit bus);

    always_ff @(posedge bus.clk ) begin
        if(bus.valid)begin
            case(bus.op)
                2'b00:begin
                    bus.result <= bus.a ^ bus.b;
                end

                2'b01:begin
                    bus.result <= bus.a << bus.b[2:0];
                end

                2'b10:begin
                    bus.result <= bus.a >> bus.b[2:0];
                end

                2'b11:begin
                    if(bus.a >= bus.b)begin
                        bus.result <= bus.a;
                    end
                    else begin
                        bus.result <= bus.b;
                    end
                end
                default:;
            endcase
        end
    end
endmodule

class Driver;
    virtual logic_if.TB vir;

    function new(virtual logic_if.TB vir);
        this.vir = vir;
    endfunction

    task run(input logic[7:0]a, input logic[7:0]b, input logic[1:0]op, input logic valid);
        begin
            vir.cb.a <= a;
            vir.cb.b <= b;
            vir.cb.op <= op;
            vir.cb.valid <= valid;
        end
    endtask
endclass

class Scoreboard;
    virtual logic_if.TB vir;
    int PASS = 0;
    
    function new(virtual logic_if.TB vir);
        this.vir = vir;
    endfunction

    function void print();
        $display("PASS: %0d", PASS);
    endfunction

    task check(input logic[9:0]expected);
        begin
            if(vir.cb.result === expected)begin
                PASS++;
                $display("expected: %0d | result: %0d", expected, vir.cb.result);
            end
            else begin
                $fatal(1,"ERROR");
            end
        end
    endtask
endclass

module Top;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic_if bus(clk);

    logicunit u_logicunit(.bus(bus));

    Driver dri;
    Scoreboard scr;

    initial begin
        dri = new(bus);
        scr = new(bus);

        //1
        @(bus.cb);
        dri.run(8'd12, 8'd10, 2'b00, 1'b1);
        @(bus.cb);@(bus.cb);
        scr.check(10'd6);

        //2
        @(bus.cb);
        dri.run(8'd3, 8'd2, 2'b01, 1'b1);
        @(bus.cb);@(bus.cb);
        scr.check(10'd12);

        //3
        @(bus.cb);
        dri.run(8'd64, 8'd3, 2'b10, 1'b1);
        @(bus.cb);@(bus.cb);
        scr.check(10'd8);

        //4
        @(bus.cb);
        dri.run(8'd90, 8'd20, 2'b11, 1'b1);
        @(bus.cb);@(bus.cb);
        scr.check(10'd90);

        //5
        @(bus.cb);
        dri.run(8'd7, 8'd100, 2'b11, 1'b1);
        @(bus.cb);@(bus.cb);
        scr.check(10'd100);

        //6
        @(bus.cb);
        dri.run(8'd255, 8'd1, 2'b00, 1'b0);
        @(bus.cb);@(bus.cb);
        scr.check(10'd100);

        scr.print();

        $finish;
    end
endmodule