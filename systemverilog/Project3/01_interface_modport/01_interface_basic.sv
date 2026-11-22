interface simple_if;
    logic [7:0]value;
    logic [8:0]result;
endinterface //simple_if

module addtwo(
    input logic [7:0]a,b,

    output logic [8:0]result
);
    assign result = a + b;
endmodule

module Top;
    simple_if bus();

    addtwo uut0(
        .a(bus.value),
        .b(bus.value),
        .result(bus.result)
    );

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