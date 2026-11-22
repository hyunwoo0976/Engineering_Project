import uvm_pkg::*;
`include "uvm_macros.svh"

class my_driver extends uvm_component;
    `uvm_component_utils(my_driver)

    function new(string name = "DRIVER", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info("DRIVER", "driver start", UVM_LOW)
        #5;
        `uvm_info("DRIVER", "driver after 5ns",UVM_LOW);
    endtask
endclass   

class my_test extends uvm_test;
    `uvm_component_utils(my_test)
    my_driver d;

    function new(string name = "TEST", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        d = my_driver::type_id::create("tx_drv", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", " test start", UVM_LOW);

        #10;
        `uvm_info("TEST", "test after 10ns", UVM_LOW);
        phase.drop_objection(this);
    endtask
endclass

module Top;
    initial begin
        run_test("my_test");
    end
endmodule

/* [코드 예상]
[TEST] test start
[DRIVER] driver start
#5 
[DRIVER]driver after 5ns
#5
[TEST]test after 10ns
*/