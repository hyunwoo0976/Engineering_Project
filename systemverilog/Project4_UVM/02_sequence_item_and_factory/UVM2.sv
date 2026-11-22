import uvm_pkg::*;
`include "uvm_macros.svh"

class my_item extends uvm_sequence_item;
    `uvm_object_utils(my_item)

    bit[7:0] data;

    function new(string name = "my_item");
        super.new(name);
    endfunction
endclass

class my_test extends uvm_test;
    `uvm_component_utils(my_test)
    my_item item;

    function new(string name = "first_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("FIRST_TEST", "START", UVM_LOW);
        item = my_item::type_id::create("item");
        item.data = 8'hA5;

        #10;
        phase.drop_objection(this);
        `uvm_info("FIRST_TEST", "END", UVM_LOW);
    endtask
endclass

module Top;
    
    initial begin
        run_test("my_test");
        
    end
endmodule