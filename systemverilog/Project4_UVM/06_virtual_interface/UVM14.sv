import uvm_pkg::*;
`include "uvm_macros.svh"

interface bus_if;
    logic valid;
    logic ready;
    logic[7:0] data;
endinterface

class my_driver extends uvm_component;
    `uvm_component_utils(my_driver)
    virtual bus_if vir;
    int driver_id;

    function new(string name = "DRIVER", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(virtual bus_if)::get(this, "", "vif", vir))begin
            `uvm_fatal("VIR ERROR", "VIR ERROR");
        end

        if(!uvm_config_db#(int)::get(this, "", "driver_id", driver_id))begin
            `uvm_fatal("DRIVER_ID_ERROR", "DRIVER_ID not connected");
        end

    endfunction

    task run_phase(uvm_phase phase);
        #2;
        if(driver_id == 1)begin
            vir.data = 8'hC3;
            vir.valid = 1'b1;
            vir.ready = 1'b1;
        end

        #2;
        if(driver_id == 2)begin
            vir.data = 8'hA1;
            vir.valid = 1'b1;
            vir.ready = 1'b1;
        end

        #2;
        if(driver_id == 3)begin
            vir.data = 8'hB2;
            vir.valid = 1'b1;
            vir.ready = 1'b1;
        end
        
    endtask

endclass

class my_monitor extends uvm_component;
    `uvm_component_utils(my_monitor)

    function new(string name = "MONITOR", uvm_component parent = null);
        super.new(name, parent);
    endfunction
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
        if(!uvm_config_db#(int)::get(this, "", "agent_id", agent_id))begin
            `uvm_fatal("AGENT_ID_ERROR", "AGENT_ID not connected");
        end

        if(agent_id == 11)begin
            uvm_config_db#(int)::set(this, "tx_drv", "driver_id", 1);
        end
        else if(agent_id == 22)begin
            uvm_config_db#(int)::set(this, "tx_drv", "driver_id", 2);
        end
        else if(agent_id == 33)begin
            uvm_config_db#(int)::set(this, "tx_drv", "driver_id", 3);
        end
        
    endfunction
endclass

class my_env extends uvm_env;
    `uvm_component_utils(my_env)
    my_agent agent_x;
    my_agent agent_y;
    my_agent agent_z;

    function new(string name = "ENV", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        agent_x = my_agent::type_id::create("agent_x", this);
        uvm_config_db#(int)::set(this, "agent_x", "agent_id", 11);
        agent_y = my_agent::type_id::create("agent_y", this);
        uvm_config_db#(int)::set(this, "agent_y", "agent_id", 22);
        agent_z = my_agent::type_id::create("agent_z", this);
        uvm_config_db#(int)::set(this, "agent_z", "agent_id", 33);
    
    endfunction
endclass

class my_test extends uvm_test;
    `uvm_component_utils(my_test)
    my_env e;
    virtual bus_if vir_x;
    virtual bus_if vir_y;
    virtual bus_if vir_z;

    function new(string name = "TEST", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        e = my_env::type_id::create("ENV", this);
        if(!uvm_config_db#(virtual bus_if)::get(this, "", "vif_x", vir_x))begin
            `uvm_fatal("INTERFACE ERROR", "bus_x error");
        end
        if(!uvm_config_db#(virtual bus_if)::get(this, "", "vif_y", vir_y))begin
            `uvm_fatal("INTERFACE ERROR", "bus_y error");
        end
        if(!uvm_config_db#(virtual bus_if)::get(this, "", "vif_z", vir_z))begin
            `uvm_fatal("INTERFACE ERROR", "bus_z error");
        end
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "start", UVM_LOW);
        #3;
        `uvm_info("TEST", $sformatf("data of bus_x: %h", vir_x.data),UVM_LOW);
        `uvm_info("TEST", $sformatf("data of bus_x: %h", vir_y.data),UVM_LOW);
        `uvm_info("TEST", $sformatf("data of bus_x: %h", vir_z.data),UVM_LOW);

        #2;
        `uvm_info("TEST", $sformatf("data of bus_x: %h", vir_x.data),UVM_LOW);
        `uvm_info("TEST", $sformatf("data of bus_x: %h", vir_y.data),UVM_LOW);
        `uvm_info("TEST", $sformatf("data of bus_x: %h", vir_z.data),UVM_LOW);

        #2;
        `uvm_info("TEST", $sformatf("data of bus_x: %h", vir_x.data),UVM_LOW);
        `uvm_info("TEST", $sformatf("data of bus_x: %h", vir_y.data),UVM_LOW);
        `uvm_info("TEST", $sformatf("data of bus_x: %h", vir_z.data),UVM_LOW);

        #10;
        `uvm_info("TEST", "end", UVM_LOW);
        phase.drop_objection(this);
    endtask
endclass

module Top;
    bus_if bus_x();
    bus_if bus_y();
    bus_if bus_z();

    initial begin
        bus_x.data = 0;
        bus_x.valid = 0;
        bus_x.ready = 0;

        bus_y.data = 0;
        bus_y.valid = 0;
        bus_y.ready = 0;

        bus_z.data = 0;
        bus_z.valid = 0;
        bus_z.ready = 0;

        uvm_config_db#(virtual bus_if)::set(null, "uvm_test_top.ENV.agent_x.tx_drv", "vif", bus_z);
        uvm_config_db#(virtual bus_if)::set(null, "uvm_test_top.ENV.agent_y.tx_drv", "vif", bus_x);
        uvm_config_db#(virtual bus_if)::set(null, "uvm_test_top.ENV.agent_z.tx_drv", "vif", bus_y);

        uvm_config_db#(virtual bus_if)::set(null, "uvm_test_top", "vif_x", bus_x);
        uvm_config_db#(virtual bus_if)::set(null, "uvm_test_top", "vif_y", bus_y);
        uvm_config_db#(virtual bus_if)::set(null, "uvm_test_top", "vif_z", bus_z);

        run_test("my_test");
    end
endmodule


