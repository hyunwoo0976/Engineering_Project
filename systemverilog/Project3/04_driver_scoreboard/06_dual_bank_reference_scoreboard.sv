interface simple_if(input logic clk);
    logic reset;
    logic valid;
    logic sel;
    logic [7:0]data;
    logic [1:0]op;
    logic [7:0]result0;
    logic [7:0]result1;

    clocking cb @(posedge clk);
        default input #1step output #0;

        output reset, valid, sel, data, op;
        input result0, result1;
    endclocking

    modport DUT_dual_bank(
        input reset,valid,sel,data,op,clk,
        output result0,result1
    );

    modport TB(
        clocking cb
    );
endinterface

module dual_bank(simple_if.DUT_dual_bank bus);
    logic [7:0]reg0, reg1;

    reg0_next_logic u_reg0_next_logic(.bus(bus), .result0(reg0));
    reg1_next_logic u_reg1_next_logic(.bus(bus), .result1(reg1));

    always_ff @(posedge bus.clk or posedge bus.reset)begin
        if(bus.reset)begin
            bus.result0 <= 0;
            bus.result1 <= 0;
        end
        else if(bus.op == 2'b11 && bus.valid)begin
            bus.result0 <= reg1;
            bus.result1 <= reg0;
        end
        else begin
            bus.result0 <= reg0;
            bus.result1 <= reg1;
        end
    end
endmodule

module reg0_next_logic(
    simple_if.DUT_dual_bank bus,
    output logic[7:0]result0 
);

    always_comb begin
        result0 = bus.result0;
        if(bus.valid && !bus.sel)begin
            case(bus.op)
                2'b00:begin
                    result0 = bus.data;
                end

                2'b01:begin
                    result0 = bus.result0 + bus.data;
                end

                2'b10:begin
                    result0 = bus.result0 - bus.data;
                end
                default:;
            endcase
        end
    end
endmodule

module reg1_next_logic(
    simple_if.DUT_dual_bank bus,
    output logic[7:0]result1    
);
    always_comb begin
        result1 = bus.result1;
        if(bus.valid && bus.sel)begin
            case(bus.op)
                2'b00:begin
                    result1 = bus.data;
                end

                2'b01:begin
                    result1 = bus.result1 + bus.data;
                end

                2'b10:begin
                    result1 = bus.result1 - bus.data;
                end
                default:;
            endcase
        end
    end
endmodule

class Driver;
    virtual simple_if.TB vir;

    function new(virtual simple_if.TB vir);
        this.vir = vir;
    endfunction

    task run(input logic[7:0]data, input logic[1:0]op, input logic sel, input logic valid, input logic reset);
        begin
            vir.cb.data <= data;
            vir.cb.op <= op;
            vir.cb.sel <= sel;
            vir.cb.valid <= valid;
            vir.cb.reset <= reset;
        end
    endtask
endclass

class Scoreboard;
    virtual simple_if.TB vir;
    logic [7:0]expected0, expected1;
    logic [7:0]temp;
    int PASS = 0;

    function new(virtual simple_if.TB vir);
        this.vir = vir;
    endfunction

    function void print();
        $display("PASS: %0d", PASS);
    endfunction

    task check;
        begin
            if(vir.cb.result0 === expected0 && vir.cb.result1 === expected1)begin
                PASS++;
            end
            else begin
                $display("result0: %0d | result1: %0d || expected0: %0d | expected1: %0d", vir.cb.result0, vir.cb.result1, expected0, expected1);
                $fatal(1, "ERROR");
            end
        end
    endtask
        

    task predict(input logic[7:0]data, input logic[1:0]op, input logic sel, input logic valid, input logic reset);
        begin
            if(reset)begin
                expected0 = 0;
                expected1 = 0;
            end
            else begin
                if(valid)begin
                    if(!sel)begin
                        case(op)
                            2'b00:begin
                                expected0 = data;
                            end

                            2'b01: begin
                                expected0 = expected0 + data;
                            end

                            2'b10:begin
                                expected0 = expected0 - data;
                            end

                            2'b11:begin
                                temp = expected0;
                                expected0 = expected1;
                                expected1 = temp;
                            end
                        endcase
                    end
                    else begin
                        case(op)
                            2'b00:begin
                                expected1 = data;
                            end

                            2'b01: begin
                                expected1 = expected1 + data;
                            end

                            2'b10:begin
                                expected1 = expected1 - data;
                            end

                            2'b11:begin
                                temp = expected1;
                                expected1 = expected0;
                                expected0 = temp;
                            end
                        endcase
                    end
                end
            end
        end
    endtask

endclass

module Top;
    logic clk = 1'b0;

    always #5 clk = ~clk;

    simple_if bus(clk);
    dual_bank u_dual_bank(.bus(bus));

    Driver dri;
    Scoreboard scr;

    initial begin
        dri = new(bus);
        scr = new(bus);

        @(bus.cb);

        // 1. reset
        dri.run    (8'd0, 2'b00, 1'b0, 1'b0, 1'b1);
        scr.predict(8'd0, 2'b00, 1'b0, 1'b0, 1'b1);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        // 2. result0에 20 LOAD
        dri.run    (8'd20, 2'b00, 1'b0, 1'b1, 1'b0);
        scr.predict(8'd20, 2'b00, 1'b0, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        // 3. result1에 7 LOAD
        dri.run    (8'd7, 2'b00, 1'b1, 1'b1, 1'b0);
        scr.predict(8'd7, 2'b00, 1'b1, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        // 4. result0에 5 ADD
        // 예상 상태: result0=25, result1=7
        dri.run    (8'd5, 2'b01, 1'b0, 1'b1, 1'b0);
        scr.predict(8'd5, 2'b01, 1'b0, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        // 5. result1에서 2 SUB
        // 예상 상태: result0=25, result1=5
        dri.run    (8'd2, 2'b10, 1'b1, 1'b1, 1'b0);
        scr.predict(8'd2, 2'b10, 1'b1, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        // 6. SWAP
        // 교환 전: result0=25, result1=5
        // 교환 후: result0=5, result1=25
        dri.run    (8'd99, 2'b11, 1'b0, 1'b1, 1'b0);
        scr.predict(8'd99, 2'b11, 1'b0, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        // 7. valid=0이므로 ADD 100 무시
        // 예상 상태 유지: result0=5, result1=25
        dri.run    (8'd100, 2'b01, 1'b0, 1'b0, 1'b0);
        scr.predict(8'd100, 2'b01, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        // 8. result0에서 10 SUB
        // 5-10은 8비트 unsigned에서 251
        dri.run    (8'd10, 2'b10, 1'b0, 1'b1, 1'b0);
        scr.predict(8'd10, 2'b10, 1'b0, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        // 9.result0=20, result1=7인 상태에서 실행
        dri.run    (8'd99, 2'b11, 1'b1, 1'b1, 1'b0);
        scr.predict(8'd99, 2'b11, 1'b1, 1'b1, 1'b0);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        // reset과 valid가 동시에 1이면 reset 우선
        dri.run    (8'd200, 2'b01, 1'b1, 1'b1, 1'b1);
        scr.predict(8'd200, 2'b01, 1'b1, 1'b1, 1'b1);
        @(bus.cb);
        dri.run(8'd0, 2'b00, 1'b0, 1'b0, 1'b0);
        @(bus.cb);
        scr.check();

        scr.print();

        $finish;
    end
endmodule