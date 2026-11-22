interface double_if;
    logic[7:0]value;
    logic[8:0]result;
    
    modport DUT_double(
        input value,
        output result
    );

    modport TB(
        output value,
        input result
    );
endinterface

module double(double_if.DUT_double bus);
    assign bus.result = bus.value + bus.value;
endmodule

class Driver;
    virtual double_if.TB vir;

    function new(virtual double_if.TB vir);
        this.vir = vir;
    endfunction

    task run;
        begin
            vir.value = 21;
            #1;
            $display("value: %0d | result: %0d", vir.value, vir.result);
        end
    endtask
endclass

module Top;
    double_if bus();
    Driver dri;

    double u_double(.bus(bus));

    initial begin
        dri = new(bus);
        dri.run();
    end
endmodule
