interface simple_if;
    logic [7:0]value;

    modport TB(
        output value
    );
endinterface

class Driver;
    virtual simple_if.TB vif;

    function new(virtual simple_if.TB vif);
        this.vif = vif;
    endfunction

    task run;
        begin
            vif.value = 42;
        end
    endtask
endclass

module Top;
    simple_if bus();
    Driver dri;

    initial begin
        dri = new(bus);
        dri.run();
        $display("value: %0d", bus.value);
    end
endmodule
