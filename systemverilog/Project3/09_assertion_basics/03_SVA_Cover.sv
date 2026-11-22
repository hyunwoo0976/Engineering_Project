/*
assert property -> 이 규칙을 어기면 안 된다.
cover property -> 이 상황이 시뮬레이션 중 실제로 발생했냐?
*/

interface simple_if(input logic clk);
    logic reset;
    logic valid;
    logic ready;
    logic[7:0]data;

    assert property(
        @(posedge clk) disable iff(reset)
        valid && !ready |=> valid && $stable(data)
    )
    else $error("ASSERT ERROR!");

    cover property(
        @(posedge clk) disable iff(reset)
        valid && !ready
    );
    cover property(
        @(posedge clk) disable iff(reset)
        valid && !ready |=> valid && ready
    );

    clocking cb @(posedge clk);
        default input #1step output #0;
        output reset, valid, ready, data;
    endclocking

    modport TB(
        clocking cb
    );
endinterface

module Top;
    logic clk = 0;
    always #5 clk = ~clk;

    simple_if bus(clk);

    initial begin
        // 초기화
        bus.cb.reset <= 1;
        bus.cb.valid <= 0;
        bus.cb.ready <= 0;
        bus.cb.data  <= 0;
        repeat (2) @(bus.cb);

        // reset 해제 후 유휴
        bus.cb.reset <= 0;
        repeat (2) @(bus.cb);

        // TODO: valid=1, ready=0, data=42로 대기 상황 만들기
        bus.cb.valid <= 1; bus.cb.ready <= 0; bus.cb.data <= 42;
        repeat(2) @(bus.cb);

        // TODO: 다음 클럭에도 valid와 data를 유지하기
        bus.cb.valid <= 1; bus.cb.ready <= 0; bus.cb.data <= 43;
        repeat(2) @(bus.cb);
        // TODO: valid=1, ready=1로 전송 완료 상황 만들기
        bus.cb.valid <= 1; bus.cb.ready <= 1; bus.cb.data <= 42;
        repeat(2) @(bus.cb);
        // TODO: 입력을 정리하고 coverage 결과를 확인한 뒤 $finish

        $finish;

    end
endmodule


