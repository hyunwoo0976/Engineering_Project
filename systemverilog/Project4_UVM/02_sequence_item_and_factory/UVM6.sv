import uvm_pkg::*;
`include "uvm_macros.svh"

class packet_item extends uvm_sequence_item;
    bit[7:0]data;

    `uvm_object_utils(packet_item)

    function new(string name = "item");
        super.new(name);
    endfunction
endclass

class packet_test extends uvm_test;
    packet_item red;
    packet_item green;
    packet_item blue;

    `uvm_component_utils(packet_test)

    function new(string name = "test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "start", UVM_LOW);

        red = packet_item::type_id::create("green_packet");
        blue = packet_item::type_id::create("red_packet");
        green = packet_item::type_id::create("blue_packet");

        red.data = 8'hA1;
        blue.data = 8'hB2;
        green.data = 8'hC3;

        #10;

        phase.drop_objection(this);
        `uvm_info("PACKET", $sformatf("name = %s | data = %h", red.get_name(), red.data), UVM_LOW);
        `uvm_info("PACKET", $sformatf("name = %s | data = %h", blue.get_name(), blue.data), UVM_LOW);
        `uvm_info("PACKET", $sformatf("name = %s | data = %h", green.get_name(), green.data), UVM_LOW);
    endtask
endclass

module Top;
    initial begin
        run_test("packet_test");
    end
endmodule