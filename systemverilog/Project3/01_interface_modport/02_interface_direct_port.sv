interface simple_if;
    logic[7:0]value;
    logic[8:0]result;
endinterface

module addtwo(simple_if bus);
    assign bus.result = bus.value + bus.value;
endmodule

module Top;
    simple_if bus();
    
    addtwo uut0(.bus(bus));

    initial begin
        bus.value = 0;

        #10;
        bus.value = 8'd7;
        #1;
        $display("result :%b", bus.result);

        bus.value = 8'd100;
        #1;
        $display("result :%b", bus.result);

        bus.value = 8'd200;
        #1;
        $display("result :%b", bus.result);
    end
endmodule