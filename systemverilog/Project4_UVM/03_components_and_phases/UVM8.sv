import uvm_pkg::*;
`include "uvm_macros.svh"

class my_driver extends uvm_component;
    `uvm_component_utils(my_driver)

    function new(string name = "DRIVER", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

class my_monitor extends uvm_component;
    `uvm_component_utils(my_monitor)

    function new(string name = "MONITOR", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

class packet_item extends uvm_sequence_item;
    bit[7:0]data;

    `uvm_object_utils(packet_item)

    function new(string name = "PACKET");
        super.new(name);
    endfunction
endclass

class my_test extends uvm_test;
    `uvm_component_utils(my_test)
    my_driver d;
    my_monitor m;

    packet_item first;
    packet_item second;


    function new(string name = "TEST", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        d = my_driver::type_id::create("tx_drv", this);
        m = my_monitor::type_id::create("rx_mon", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        first = packet_item::type_id::create("alpha");
        second = packet_item::type_id::create("beta");

        first.data = 8'h3C;
        second.data = 8'hA5;

        `uvm_info("TEST", $sformatf("%s | %s || %s => %h || %s => %h", d.get_full_name(), m.get_full_name(), first.get_name(), first.data, second.get_name(), second.data), UVM_LOW);
        #10;

        phase.drop_objection(this);
    endtask
endclass

module Top;
    initial begin
        run_test("my_test");
    end
endmodule

