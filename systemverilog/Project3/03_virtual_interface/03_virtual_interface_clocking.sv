interface calc_if(input logic clk);
    logic[7:0] value;
    logic[8:0] result;
    logic valid;

    clocking cb @(posedge clk);
        default input #1step output #0;
        output valid, value;
        input result;
    endclocking

    modport DUT_double(
        input valid, value,clk,
        output result
    );

    modport TB(
        clocking cb
    );
endinterface

module double(calc_if.DUT_double bus);

    always_ff @(posedge bus.clk)begin
        if(bus.valid)begin
            bus.result <= bus.value + bus.value;
        end
    end
endmodule

class Driver;
    virtual calc_if.TB vir;

    function new(virtual calc_if.TB vir);
        this.vir = vir;
    endfunction

    task run(input logic [7:0]value, input logic valid);
        begin
            @(vir.cb);
            vir.cb.value <= value;
            vir.cb.valid <= valid;
            @(vir.cb); @(vir.cb);
            $display("result: %0d", vir.cb.result);
        end
    endtask

    task check(input logic [8:0] expected);
        if (vir.cb.result !== expected)
            $fatal(1, "expected=%0d actual=%0d",
                expected, vir.cb.result);
        else
            $display("PASS: result=%0d", vir.cb.result);
    endtask
endclass

module Top;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    calc_if bus(clk);
    Driver dri;

    double u_double(.bus(bus));

    initial begin
        dri = new(bus);
        dri.run(9'd30, 1'b1);
        dri.check(9'd60);

        dri.run(9'd20, 1'b1);
        dri.check(9'd40);

        dri.run(9'd200, 1'b0);
        dri.check(9'd40);
        $finish;
    end
endmodule
