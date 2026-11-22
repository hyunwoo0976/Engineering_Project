import uvm_pkg::*;
`include "uvm_macros.svh"

class my_item extends uvm_sequence_item;
    bit [7:0]data;
    `uvm_object_utils(my_item)

    function new(string name = "my_item");
        super.new(name);
    endfunction

    function void print();
        $display("data=%h", data);
    endfunction
endclass

class my_test extends uvm_test;
    `uvm_component_utils(my_test)
    my_item request;

    function new(string name = "my_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("FIRST_TEST","test_start", UVM_LOW);

        request = my_item::type_id::create("first_packet");
        request.data = 8'hA5;

        request.print();

        #10;
        phase.drop_objection(this);
        `uvm_info("FIRST_TEST", "test_end", UVM_LOW);
    endtask
endclass

module Top;
    initial begin
        run_test("my_test");
    end
endmodule

        
