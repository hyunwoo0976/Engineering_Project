interface scale_if;
    logic[7:0]data;
    logic enable;
    logic[9:0]result;
    logic valid;

    modport DUT_mul(
        input data,
        input enable,
        output result,
        output valid
    );

    modport tester(
        output data,
        output enable,
        input result,
        input valid
    );
endinterface

module multi(scale_if.DUT_mul bus);
    always_comb begin
        bus.result = 10'b0;
        bus.valid = 1'b0;
        if(bus.enable)begin
            bus.result = bus.data * 3;
            bus.valid = 1'b1;
        end
        else begin
            bus.valid = 1'b0;
        end
    end
endmodule

module tester(scale_if.tester bus);
    initial begin
        #10;

        bus.data = 5;
        bus.enable = 1;
        #1
        $display("result: %0d, valid: %b", bus.result, bus.valid);

        bus.data = 20;
        bus.enable = 0;
        #1
        $display("result: %0d, valid: %b", bus.result, bus.valid);

        bus.data = 200;
        bus.enable = 1;
        #1
        $display("result: %0d, valid: %b", bus.result, bus.valid);
    end
endmodule

module Top;
    scale_if bus();

    multi u_multi(.bus(bus));
    tester u_tester(.bus(bus));
endmodule