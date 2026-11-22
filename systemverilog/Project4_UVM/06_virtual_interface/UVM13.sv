import uvm_pkg::*;
`include "uvm_macros.svh"

interface bus_if;
    logic valid;
    logic [7:0]data;
endinterface

class my_driver extends uvm_component;
    `uvm_component_utils(my_driver)
    virtual bus_if vir;
    int driver_id;

    function new(string name = "DRIVER", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(int)::get(this, "", "driver_id", driver_id))begin
            `uvm_fatal("NO_ID", "driver id not set");
        end


        if(!uvm_config_db#(virtual bus_if)::get(this, "", "vif", vir))begin
            `uvm_fatal("NO_VIF", "interface not connected")
        end
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info("DRIVER", this.get_full_name(), UVM_LOW);
        if(driver_id == 1)begin
            vir.valid = 1'b1;
            vir.data = 8'hA1;
        end
        if(driver_id == 2)begin
            vir.valid = 1'b0;
            vir.data = 8'hB2;
        end
    endtask
endclass

class my_monitor extends uvm_component;
    `uvm_component_utils(my_monitor)

    function new(string name = "MONITOR", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info("MONITOR", this.get_full_name(), UVM_LOW);
    endtask
endclass

class my_agent extends uvm_agent;
    `uvm_component_utils(my_agent)
    my_driver d;
    my_monitor m;
    int agent_id;

    function new(string name = "AGENT", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        d = my_driver::type_id::create("tx_drv", this);
        m = my_monitor::type_id::create("rx_mon", this);
        
        uvm_config_db#(int)::get(this, "", "agent_id", agent_id);
        if(agent_id == 11)begin
            uvm_config_db#(int)::set(this, "tx_drv","driver_id", 1);
        end
        else if(agent_id == 22)begin
            uvm_config_db#(int)::set(this, "tx_drv","driver_id", 2);
        end
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
        agent1 = my_agent::type_id::create("Agent1", this);
        agent2 = my_agent::type_id::create("aGent2", this);
        uvm_config_db#(int)::set(this, "Agent1", "agent_id", 11);
        uvm_config_db#(int)::set(this, "aGent2", "agent_id", 22);
    endfunction
endclass

class my_test extends uvm_test;
    `uvm_component_utils(my_test)
    my_env e;

    function new(string name = "TEST", uvm_component parent  = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        e = my_env::type_id::create("ENV", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "start", UVM_LOW);
        #10;
        `uvm_info("TEST", "end", UVM_LOW);
        phase.drop_objection(this);
    endtask
endclass

module Top;
    bus_if bus_a();
    bus_if bus_b();

    initial begin
        uvm_config_db#(virtual bus_if)::set(null, "uvm_test_top.ENV.Agent1.tx_drv", "vif", bus_a);
        uvm_config_db#(virtual bus_if)::set(null, "uvm_test_top.ENV.aGent2.tx_drv", "vif", bus_b);

        run_test("my_test");
    end
endmodule





