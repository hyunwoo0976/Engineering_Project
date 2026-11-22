import uvm_pkg::*;
`include "uvm_macros.svh"

class my_driver extends uvm_component;
    `uvm_component_utils(my_driver)

    function new(string name = "DRIVER", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

class my_test extends uvm_test;
    `uvm_component_utils(my_test)
    my_driver input_driver;
    my_driver output_driver;
    
    function new(string name = "my_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        input_driver = my_driver::type_id::create("input_drv", this);
        output_driver = my_driver::type_id::create("output_drv", this);
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info("TEST", $sformatf("input : %s", input_driver.get_full_name()), UVM_LOW);
        `uvm_info("TEST", $sformatf("output : %s", output_driver.get_full_name()), UVM_LOW);

    endtask
endclass

module Top;
    initial begin
        run_test("my_test");
    end
endmodule

