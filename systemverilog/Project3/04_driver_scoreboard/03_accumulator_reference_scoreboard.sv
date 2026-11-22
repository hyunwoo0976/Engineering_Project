interface simple_if(input logic clk);
    logic [7:0]data;
    logic[1:0]op;
    logic valid;
    logic reset;
    logic [7:0]result;

    clocking cb @(posedge clk);
        default input #1step output #0;

        output data, op, valid,reset;
        input result;
    endclocking

    modport DUT_calculate(
        input data,op,valid,clk,reset,
        output result
    );

    modport TB(
        clocking cb
    );
endinterface

module calculate(simple_if.DUT_calculate bus);

    always_ff @(posedge bus.clk or posedge bus.reset)begin
        if(bus.reset)begin
            bus.result <= 8'd0;
        end
        else begin
            if(bus.valid)begin
                case(bus.op)
                    2'b00:begin
                        bus.result <= bus.data;
                    end
                    
                    2'b01:begin
                        bus.result <= bus.result + bus.data;
                    end

                    2'b10:begin
                        bus.result <= bus.result - bus.data;
                    end

                    2'b11:begin
                        bus.result <= bus.result ^ bus.data;
                    end
                    default:;
                endcase
            end
        end
    end
endmodule

class Driver;
    virtual simple_if.TB vir;
    
    function new(virtual simple_if.TB vir);
        this.vir = vir;
    endfunction

    task run(input logic[7:0]data, input logic[1:0]op, input logic valid, input logic reset);
        begin
            vir.cb.data <= data;
            vir.cb.op <= op;
            vir.cb.valid <= valid;
            vir.cb.reset <= reset;
        end
    endtask
endclass

class Scoreboard;
    virtual simple_if.TB vir;
    logic [7:0]expected;
    int PASS = 0;

    function new(virtual simple_if.TB vir);
        this.vir = vir;
    endfunction

    function void print();
        $display("PASS: %0d", PASS);
    endfunction

    task run(input logic[7:0]data, input logic[1:0]op, input logic valid, input logic reset);
        begin
            if(reset)begin
                expected = 0;
            end
            else begin
                if(valid)begin
                    case(op)
                        2'b00:begin
                            expected = data;
                        end
                        
                        2'b01:begin
                            expected = expected + data;
                        end

                        2'b10:begin
                            expected = expected - data;
                        end

                        2'b11:begin
                            expected = expected ^ data;
                        end
                        default:;
                    endcase  
                end
            end
        end
    endtask

    task check;
        begin
            if(expected === vir.cb.result)begin
                $display("expected : %0d | result: %0d", expected, vir.cb.result);
                PASS++;
            end
            else begin
                $fatal(1,"ERROR!!! || expected : %0d | result: %0d", expected, vir.cb.result);
            end
        end
    endtask

endclass

module Top;
    logic clk = 1'b0;

    Driver dri;
    Scoreboard scr;

    always #5 clk = ~clk;

    simple_if bus(clk);

    calculate u_calculate(.bus(bus));

    initial begin
        dri = new(bus);
        scr = new(bus);

        @(bus.cb);

        //1
        dri.run(8'd99, 2'b00, 1'b0, 1'b1);
        scr.run(8'd99, 2'b00, 1'b0, 1'b1);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        //2
        dri.run(8'd10, 2'b00, 1'b1, 1'b0);
        scr.run(8'd10, 2'b00, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        //3
        dri.run(8'd5, 2'b01, 1'b1, 1'b0);
        scr.run(8'd5, 2'b01, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        //4
        dri.run(8'd3, 2'b11, 1'b1, 1'b0);
        scr.run(8'd3, 2'b11, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        //5
        dri.run(8'd100, 2'b01, 1'b0, 1'b0);
        scr.run(8'd100, 2'b01, 1'b0, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        //6
        dri.run(8'd7, 2'b10, 1'b1, 1'b0);
        scr.run(8'd7, 2'b10, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        //7
        dri.run(8'd250, 2'b01, 1'b1, 1'b0);
        scr.run(8'd250, 2'b01, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        //8
        dri.run(8'd2, 2'b01, 1'b1, 1'b0);
        scr.run(8'd2, 2'b01, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        //9
        dri.run(8'd100, 2'b01, 1'b1, 1'b1);
        scr.run(8'd100, 2'b01, 1'b1, 1'b1);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        scr.print();

        $finish;
    end
endmodule