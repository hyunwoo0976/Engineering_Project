import uvm_pkg::*;
`include "uvm_macros.svh"

class review_item extends uvm_sequence_item;
    bit[7:0]data;
    `uvm_object_utils(review_item)

    function new(string name = "review_item");
        super.new(name);
    endfunction
endclass

class review_test extends uvm_test;
    `uvm_component_utils(review_test)
    review_item req;

    function new(string name = "review_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("review test", "start", UVM_LOW);

        req = review_item::type_id::create("packet_1");
        req.data = 8'h3C;

        $display("data = %0h", req.data);

        #1;
        phase.drop_objection(this);
        `uvm_info("review test", "end", UVM_LOW);
    endtask
endclass

module Top;
    initial begin
        run_test("review_test");
    end
endmodule


