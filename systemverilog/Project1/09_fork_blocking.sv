/*
이번 건 지금까지 안 본 각도예요: fork랑 blocking(기다림)이 실제로 어떻게 도는지를 "시간"으로 눈에 보이게 하는 거예요. 아까 당신이 헷갈렸던 "소비자가 get에서 기다린다"는 걸 직접 눈으로 확인하는 문제라, 이거 하고 나면 fork/mailbox 감이 확실해져요.

🎯 3강 문제 3 (solv7.sv) — "기다림을 눈으로 보기"
⚠️ 맨 첫 줄에 이거 꼭 넣기 (시간 단위 지정, 안 넣으면 빌드 에러날 수 있어요):

`timescale 1ns/1ps
만들 것 (코드는 당신이):

Transaction — rand bit [7:0] data; (print는 원하면)
Producer (생산자) — 생성자로 mb 받고:
task run;
    repeat(10)begin
        Transaction handle = new();
        if(handle.randomize() == 0) $fatal(1,"error");
        #10;                        // ← 10ns 기다렸다가 (일부러 천천히 생산)
        mb.put(handle);
        $display("[%0t] 생산: data=%h 보냄", $time, handle.data);
    end
endtask
Consumer (소비자) — 생성자로 같은 mb 받고:
task run;
    repeat(10)begin
        Transaction handle;
        mb.get(handle);             // ← 물건 올 때까지 여기서 멈춰서 기다림
        $display("[%0t] 소비: data=%h 받음", $time, handle.data);
    end
endtask
(소비자는 delay 없음 — 빠름. 그래서 get에서 기다리기만 함)

Top — mailbox 1개, producer·consumer 만들어서 같은 mb 연결, fork...join
👀 관찰 포인트 (이게 핵심)
출력의 시간 [숫자] 를 보세요. 이렇게 나올 거예요:

[10] 생산: ... 보냄
[10] 소비: ... 받음      ← 생산하자마자 소비가 바로!
[20] 생산: ... 보냄
[20] 소비: ... 받음
...
왜 같은 시간에 붙어서 나오냐? → 소비자는 get에서 멈춰서 자고 있다가(blocking), 생산자가 put하는 그 순간 깨어나서 받아요. 이게 fork(둘이 동시에 삶) + blocking(없으면 기다림)의 실체예요. 아까 "task는 불러야 돌고, get은 기다린다" 했던 그 얘기가 시간으로 증명되는 거죠.

🔥 실험
fork...join을 지우고 순차로 바꿔봐요:

gen.run();   // fork 없이
con.run();
→ 이번엔 생산이 [10]~[100]에 다 끝난 뒤에 소비가 [100]에 몰려서 10개 한꺼번에 나와요. 시간 패턴이 확 달라지죠. fork가 왜 필요한지가 눈에 보여요.

(⚠️ 순서를 con.run(); gen.run();로 하면 소비자가 빈 벨트에서 영원히 기다려서 멈춰버려요(deadlock). 그러면 Ctrl+C로 끄면 돼요 — 이것도 좋은 실험이에요, "왜 순차로 하면 안 되나".)

svrun ./systemverilog/Project1/solv7.sv
짜서 돌려보고 시간 출력 붙여줘요. 같이 해석해봐요. 이거 이해되면 fork/mailbox는 진짜 끝이에요.


저장됨 메모리 1개
Ready. solv7 돌려서 시간 출력 붙여주면 같이 해석할게요
*/
`timescale 1ns/1ps
class Transaction;
    rand bit[7:0]data;

    function void print();
        $display ("time: [%0t] || data: %h", $time, data);
    endfunction
endclass

class Producer;
    mailbox #(Transaction)mb;

    function new(mailbox #(Transaction)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(10)begin
                Transaction handle = new();
                if(handle.randomize() == 0)begin
                    $fatal(1, "ERROR");
                end
                #10;
                mb.put(handle);
                handle.print();
            end
        end
    endtask
endclass

class Consumer;
    mailbox #(Transaction)mb;

    function new(mailbox #(Transaction)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(10)begin
                Transaction handle;
                mb.get(handle);
                handle.print();
            end
        end
    endtask
endclass

module Top;
    mailbox #(Transaction)mb = new();

    Producer pro = new(mb);
    Consumer con = new(mb);

    initial begin
        pro.run();
        con.run();
    end
endmodule

