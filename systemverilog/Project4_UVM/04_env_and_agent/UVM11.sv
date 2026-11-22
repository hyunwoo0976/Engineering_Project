import uvm_pkg::*;
`include "uvm_macros.svh"

class my_driver extends uvm_component;
    `uvm_component_utils(my_driver)

    function new(string name = "DRIVER", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info("DRIVER", $sformatf("driver: %s", this.get_full_name()),UVM_LOW);
    endtask
endclass

class my_monitor extends uvm_component;
    `uvm_component_utils(my_monitor)

    function new(string name = "MONITOR", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info("MONITOR", $sformatf("monitor: %s", this.get_full_name()),UVM_LOW);
    endtask
endclass

class my_agent extends uvm_agent;
    `uvm_component_utils(my_agent)
    my_driver d;
    my_monitor m;

    function new(string name = "AGENT", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        d = my_driver::type_id::create("tx_drv",this);
        m = my_monitor::type_id::create("rx_mon",this);
    endfunction

endclass

class my_env extends uvm_env;
    `uvm_component_utils(my_env)
    my_agent agent1;
    my_agent agent2;

    function new(string name = "ENV", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        agent1 = my_agent::type_id::create("agent1",this);
        agent2 = my_agent::type_id::create("agent2",this);
    endfunction

endclass

class my_test extends uvm_test;
    `uvm_component_utils(my_test)
    my_env e;

    function new(string name = "TEST", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        e = my_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "START", UVM_LOW);

        #10;
        `uvm_info("TEST", $sformatf("agent1: %s | agent2: %s", e.agent1.get_full_name(), e.agent2.get_full_name()),UVM_LOW);
        phase.drop_objection(this);

    endtask

endclass

module Top;
    initial begin
        run_test("my_test");
    end
endmodule