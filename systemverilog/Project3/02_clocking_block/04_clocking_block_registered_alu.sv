interface alu_if(input logic clk);
    logic[7:0]a,b;
    logic[8:0]result;
    logic [1:0]op;
    logic valid;

    clocking cb @(posedge clk);
        default input #1step output #0;
        input result,valid;
        output a,b,op;
    endclocking

    modport DUT_ALU(
        input a,b,op,clk,
        output result,valid
    );

    modport TB(
        clocking cb
    );
endinterface

module ALU(alu_if.DUT_ALU bus);
    logic [8:0]next_result;
    logic next_valid;

    logic mont;

    always_comb begin
        mont = (bus.a >= bus.b) ? 1'b1 : 1'b0;
        case(bus.op)
            2'b00:begin //ADD
                next_result = bus.a + bus.b;
                next_valid = 1'b1;
            end

            2'b01:begin //a>=b면 a-b, 아니면 b-a, next_valid=1
                next_valid = 1'b1;
                if(mont)begin
                    next_result = bus.a - bus.b;
                end
                else begin
                    next_result = bus.b - bus.a;
                end
            end

            2'b10:begin //a>=b면 a, 아니면 b, next_valid=1
                next_valid = 1'b1;
                if(mont)begin
                    next_result = bus.a;
                end
                else begin
                    next_result = bus.b;
                end
            end

            default:begin
                next_valid = 1'b0;
            end
        endcase
    end

    always_ff @(posedge bus.clk)begin
        bus.result <= next_result;
        bus.valid <= next_valid;
    end
endmodule

module tester(alu_if.TB bus);
    task automatic check_case(
        input logic [7:0] a,
        input logic [7:0] b,
        input logic [1:0] op,
        input logic [8:0] expected_result,
        input logic expected_valid,
        input string test_name
    );
        bus.cb.a  <= a;
        bus.cb.b  <= b;
        bus.cb.op <= op;
        @(bus.cb); @(bus.cb);

        if ((bus.cb.result !== expected_result) ||
            (bus.cb.valid !== expected_valid)) begin
            $fatal(1,
                "FAIL %s: result=%0d valid=%b, expected result=%0d valid=%b",
                test_name, bus.cb.result, bus.cb.valid,
                expected_result, expected_valid);
        end
        $display("PASS %s: result=%0d valid=%b",
                 test_name, bus.cb.result, bus.cb.valid);
    endtask

    initial begin
        @(bus.cb);

        check_case(0,   0,   2'b00, 0,   1'b1, "ADD zero");
        check_case(200, 100, 2'b00, 300, 1'b1, "ADD normal");
        check_case(255, 255, 2'b00, 510, 1'b1, "ADD max");

        check_case(55, 20, 2'b01, 35, 1'b1, "ABSDIFF a>b");
        check_case(20, 55, 2'b01, 35, 1'b1, "ABSDIFF a<b");
        check_case(9,   9, 2'b01, 0,  1'b1, "ABSDIFF equal");

        check_case(99, 7,  2'b10, 99, 1'b1, "MAX a>b");
        check_case(7,  99, 2'b10, 99, 1'b1, "MAX a<b");
        check_case(9,   9, 2'b10, 9,  1'b1, "MAX equal");

        check_case(100, 23, 2'b00, 123, 1'b1, "INVALID hold seed");
        check_case(12,   3, 2'b11, 123, 1'b0, "INVALID hold");

        $display("ALL TESTS PASS");
        $finish;
    end
endmodule

module Top;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    alu_if bus(clk);

    ALU u_ALU(.bus(bus));
    tester u_tester(.bus(bus));
endmodule
