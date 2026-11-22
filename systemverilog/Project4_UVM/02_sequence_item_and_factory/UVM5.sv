import uvm_pkg::*;
`include "uvm_macros.svh"

class packet_item extends uvm_sequence_item;
    `uvm_object_utils(packet_item)
    bit[7:0]first_data;
    bit[7:0]second_data;

    function new(string name = "item");
        super.new(name);
    endfunction
endclass

class packet_test extends uvm_test;
    packet_item first;
    packet_item second;

    `uvm_component_utils(packet_test)

    function new(string name = "test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "start", UVM_LOW);

        first = packet_item::type_id::create("second_packet");
        second = packet_item::type_id::create("first_packet");

        first.first_data = 8'h12;
        second.second_data = 8'h34;

        #10;
        phase.drop_objection(this);
        `uvm_info("TEST","end", UVM_LOW);
    endtask
endclass

module Top;
    initial begin
        run_test("packet_test");
    end
endmodule