interface simple_if;
    logic[7:0]value;
    logic[8:0]result;

    modport DUT_addtwo (
        input value,
        output result
    );

    modport TB_Top(
        output value,
        input result
    );
endinterface

module addtwo(simple_if.DUT_addtwo bus);
    assign bus.result = bus.value + bus.value;
endmodule

module Top;
    simple_if bus();

    addtwo DUT(.bus(bus));

    initial begin
        bus.value = 0;

        #10;
        bus.value = 7;
        #1;
        $display("result: %0d", bus.result);

        bus.value = 100;
        #1;
        $display("result: %0d", bus.result);

        bus.value = 200;
        #1;
        $display("result: %0d", bus.result);
    end
endmodule