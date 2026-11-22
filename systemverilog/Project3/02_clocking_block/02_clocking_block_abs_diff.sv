interface diff_if(input logic clk);
    logic[7:0] x,y;
    logic[8:0] diff;

    clocking cb @(posedge clk);
        default input #1step output #0;
        output x,y;
        input diff;
    endclocking

    modport DUT_diff(
        input x,y,clk,
        output diff
    );

    modport TB(
        clocking cb
    );

endinterface

module diff (
    diff_if.DUT_diff bus
);
    logic [7:0]a,b;

    always_comb begin
        if(bus.x >= bus.y)begin
            a = bus.x;
            b = bus.y;
        end
        else begin
            a = bus.y;
            b = bus.x;
        end
    end
    always_ff @(posedge bus.clk) begin
        bus.diff <= a - b;
    end
endmodule

module tester(diff_if.TB bus);
    initial begin
        @(bus.cb);

        bus.cb.x <= 50; bus.cb.y <= 8;
        @(bus.cb);@(bus.cb);
        $display("diff: %0d", bus.cb.diff);

        bus.cb.x <= 6; bus.cb.y <= 19;
        @(bus.cb);@(bus.cb);
        $display("diff: %0d", bus.cb.diff);

        bus.cb.x <= 9; bus.cb.y <= 9;
        @(bus.cb);@(bus.cb);
        $display("diff: %0d", bus.cb.diff);

        $finish;
    end
endmodule

module Top;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    diff_if bus(clk);

    diff u_diff(.bus(bus));
    tester u_tester(.bus(bus));
endmodule