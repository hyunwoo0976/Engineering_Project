import uvm_pkg::*;
`include "uvm_macros.svh"

class first_test extends uvm_test;
    `uvm_component_utils(first_test)

    function new(string name = "test_first", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info("FIRST_TEST", "시작", UVM_LOW);
        phase.raise_objection(this);

        #10;
        `uvm_info("FIRST_TEST", "끝", UVM_LOW);

        phase.drop_objection(this);
    endtask
endclass

module Top;
    initial begin
        run_test("first_test");
    end
endmodule