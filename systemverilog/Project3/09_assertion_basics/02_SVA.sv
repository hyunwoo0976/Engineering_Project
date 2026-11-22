/*
assert property(
    @(posedge clk) disable iff(reset)   //매클럭 상승 엣지에서 확인, reset 중에는 검사 비활성화
    valid && !ready |=> valid && $stable(data)  //현재 클럭에 전송 대기 중이면 , valid가 1이고 data가 이전 클럭과 같아야함.
)
else $error("FAIL: waiting data changed");

assert는 "이 조건이 참이어야 한다"고 검사하는 문법

assert(조건)
    $display("PASS");
else
    $error("FAIL");
이거는 실행되는 그 순간의 조건을 검사하는 즉시 assertion.

반면 assert property (...)는 클럭을 따라 시간 관계까지 검사할때 사용. property는 반드시 지켜야 할 동작 규칙 이라고 생각하면됨.

assert property(
    @(posedge clk)
    A |=> B
);

이건 매 상승 엣지에서 A를 확인하고, A가 참이었다면 다음 상승 엣지에서 B가 참인지 검사한다.
|=> 는 세 글자가 합쳐진 하나의 연산자. 여기의 |를 OR로 , =>를 별도로 나눠 읽으면 안됌.
A |=> B: 지금 A가 참이면 다음검사 클럭에서 B가 참이어야한다.

$stable(data)는 'data'가 이전 검사 클럭의 값과 같은가? 를 확인하는 함수

즉, valid && !ready |=> valid && $stable(data) 라는 뜻은
지금 valid가 1이고 ready가 0이면, 다음 클럭에도 valid가 1이어야하고 data는 지금 클럭에서 본 값과 같아야한다.

$display(...) : 메세지만 출력
$warning(...) : 경고를 보고하고 보통 계속 실행
$error(...) : 오류를 보고하고 보통 계속 실행
$fatal(1, ...) : 치명적 오류를 보고하고 시뮬레이션 종료
*/

interface simple_if(input logic clk);
    logic reset;
    logic valid;
    logic ready;
    logic [7:0]data;
    logic [7:0]out_data;

    assert property(
        @(posedge clk) disable iff(reset)
        !(valid && ready) |=> $stable(out_data)
    )
        $display("PASS assert!!");
    else $error("FAIL: out_data changed without transfer");

    clocking cb @(posedge clk);
        default input #1step output #0;
        output reset, valid, ready, data;
        input out_data;
    endclocking


    modport DUT_simple(
        input reset, clk, valid, ready,data,
        output out_data
    );

    modport TB(
        clocking cb
    );

endinterface


module simple(simple_if.DUT_simple bus);
    always_ff @( posedge bus.clk or posedge bus.reset ) begin 
        if(bus.reset)begin
            bus.out_data <= 0;
        end
        else begin
            if(bus.valid && bus.ready)begin
                bus.out_data <= bus.data;
            end
        end
    end
endmodule


class Transaction;
    rand logic reset;
    rand logic valid;
    rand logic ready;
    rand logic [7:0]data;

    constraint urand{
        reset dist{1'b0:/9, 1'b1:/1};
        valid dist{1'b0:/3, 1'b1:/7};
        ready dist{1'b0:/5, 1'b1:/5};
    }
endclass


class Generator;
    Transaction handle;
    mailbox #(Transaction)gen2dri;

    function new(mailbox #(Transaction)gen2dri);
        this.gen2dri = gen2dri;
    endfunction

    function void print();
        $display("reset: %b | valid: %b | ready: %b | data: %b", handle.reset, handle.valid, handle.ready, handle.data);
    endfunction

    task run;
        begin
            handle = new();
            if(!handle.randomize())begin
                $fatal(1,"ERROR");
            end
            gen2dri.put(handle);
        end
    endtask

    task reset;
        begin
            handle = new();
            handle.reset = 1;
            handle.valid = 0;
            handle.ready = 0;
            handle.data = 0;
            gen2dri.put(handle);
        end
    endtask
endclass

class Driver;
    Transaction handle;
    virtual simple_if.TB vir;
    mailbox #(Transaction)gen2dri;
    mailbox #(Transaction)dri2scr;

    function new(mailbox #(Transaction)gen2dri, mailbox #(Transaction)dri2scr, virtual simple_if.TB vir);
        this.gen2dri = gen2dri;
        this.dri2scr = dri2scr;
        this.vir = vir;
    endfunction

    task run;
        begin
            gen2dri.get(handle);
            vir.cb.reset <= handle.reset;
            vir.cb.valid <= handle.valid;
            vir.cb.ready <= handle.ready;
            vir.cb.data <= handle.data;
            dri2scr.put(handle);
            @(vir.cb);@(vir.cb);
        end
    endtask
endclass


class Observation;
    logic [7:0]actual_out_data;
endclass


class Monitor;
    Observation obs;
    mailbox #(Observation)mon2scr;
    virtual simple_if.TB vir;

    function new(mailbox #(Observation)mon2scr,  virtual simple_if.TB vir);
        this.mon2scr = mon2scr;
        this.vir = vir;
    endfunction

    task run;
        begin
            @(vir.cb);
            obs = new();
            obs.actual_out_data = vir.cb.out_data;
            mon2scr.put(obs);
        end
    endtask
endclass

class Scoreboard;
    Transaction tra;
    Observation obs;

    mailbox #(Transaction)dri2scr;
    mailbox #(Observation)mon2scr;

    logic [7:0]expected_data;
    logic [7:0]tmp_data;


    int PASS = 0;

    function void print();
        $display("PASS: %0d", PASS);
    endfunction

    function new(mailbox #(Transaction)dri2scr, mailbox #(Observation)mon2scr);
        this.dri2scr = dri2scr;
        this.mon2scr = mon2scr;
    endfunction

    task run;
        begin
            dri2scr.get(tra);
            if(tra.reset)begin
                expected_data = 0;
                tmp_data = 0;
            end
            else begin
                tmp_data = expected_data;
                if(tra.valid && tra.ready)begin
                    expected_data = tra.data;
                end
                else begin
                    expected_data = tmp_data;
                end
            end
        end
    endtask

    task check;
        begin
            mon2scr.get(obs);

            if(expected_data === obs.actual_out_data)begin
                PASS++;
            end
            else begin
                $display("expected: %b || actual: %b", expected_data, obs.actual_out_data);
                $fatal(1,"ERROR");
            end
        end
    endtask
endclass

        

module Top;
    mailbox #(Transaction) gen2dri = new();
    mailbox #(Transaction) dri2scr = new();
    mailbox #(Observation) mon2scr = new();

    Transaction tra;
    Observation obs;

    Generator gen;
    Driver dri;
    Monitor mon;
    Scoreboard scr;

    logic clk = 0;
    always #5 clk = ~clk;
    simple_if bus(clk);

    simple u_simple(.bus(bus));

    initial begin
        gen = new(gen2dri);
        dri = new(gen2dri, dri2scr, bus);
        mon = new(mon2scr, bus);
        scr = new(dri2scr, mon2scr);

        gen.reset();
        gen.print();
        dri.run();
        mon.run();
        scr.run();
        scr.check();

        repeat(50)begin
            gen.run();
            gen.print();
            dri.run();
            mon.run();
            scr.run();
            scr.check();
        end

        scr.print();
        $finish;
    end

endmodule