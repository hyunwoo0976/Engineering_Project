interface simple_if;
    logic[7:0] a,b;
    logic[8:0] sum;

    modport DUT_adder(
        input a, b,
        output sum
    );
    modport tester(
        output a,b,
        input sum
    );


endinterface

module adder(simple_if.DUT_adder bus);
    assign bus.sum = bus.a + bus.b;
endmodule

module tester(simple_if.tester bus);
    initial begin
        bus.a = 8'd3;
        bus.b = 8'd4;

        #1;

        $display("result: %0d", bus.sum);
    end
endmodule

module Top;
    simple_if bus();

    adder DUT(.bus(bus));
    tester test(.bus(bus));
endmodule