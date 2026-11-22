/*left=12, right=7  → maximum=12
left=5,  right=18 → maximum=18
left=9,  right=9  → maximum=9
큰값을 저장하는회로
*/

interface max_if(input logic clk);
    logic[7:0] r,l;
    logic[7:0] max;

    clocking cb @(posedge clk);
        default input #0 output #0;
        output r,l;
        input max;
    endclocking

    modport DUT_max(
        input r,l,clk,
        output max
    );

    modport TB(
        clocking cb
    );
endinterface

module Maxselecter(max_if.DUT_max bus);
    always_ff @(posedge bus.clk)begin
        if(bus.r >= bus.l)begin
            bus.max <= bus.r;
        end
        else begin
            bus.max <= bus.l;
        end
    end
endmodule

module tester(max_if.TB bus);
    initial begin

        @(bus.cb);
        bus.cb.l <= 12; bus.cb.r <= 7;
        @(bus.cb);@(bus.cb);
        $display("maximum : %0d", bus.cb.max);


        bus.cb.l <= 5;  bus.cb.r <= 18;
        @(bus.cb);@(bus.cb);
        $display("maximum : %0d", bus.cb.max);


        bus.cb.l <= 9;  bus.cb.r <= 9;
        @(bus.cb);@(bus.cb);
        $display("maximum : %0d", bus.cb.max);

        $finish;
    end
endmodule

module Top;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    max_if bus(clk);

    Maxselecter u_max(.bus(bus));
    tester u_tester(.bus(bus));
endmodule

