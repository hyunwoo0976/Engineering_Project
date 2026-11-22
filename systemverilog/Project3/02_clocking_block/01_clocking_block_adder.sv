interface adder_if(input logic clk);
    logic [7:0]a,b;
    logic [8:0]c;

    clocking cb@(posedge clk);
        default input #1step output #0;
        output a, b;
        input c;
    endclocking

    modport DUT_adder(
        input a, b,clk,
        output c
    );

    modport TB(
        clocking cb
    );
endinterface

module adder(adder_if.DUT_adder bus);
    
    always_ff @(posedge bus.clk) begin
        bus.c <= bus.a + bus.b;
    end
endmodule

module tester(adder_if.TB bus);
    initial begin
        @(bus.cb);
    
        bus.cb.a <= 10;
        bus.cb.b <= 44;
        @(bus.cb);@(bus.cb);
        $display("result : %0d",bus.cb.c);

        @(bus.cb);

        bus.cb.a <= 0;
        bus.cb.b <= 0;
        @(bus.cb); @(bus.cb);
        $display("result : %0d", bus.cb.c);

        @(bus.cb);

        bus.cb.a <= 20;
        bus.cb.b <= 19;
        @(bus.cb); @(bus.cb);
        $display("result : %0d", bus.cb.c);
        $finish;
    end
endmodule

module Top;
    logic clk = 1'b0;

    always #5 clk = ~clk;

    adder_if bus(clk);

    adder u_adder(.bus(bus));
    tester u_tester(.bus(bus));


endmodule
    