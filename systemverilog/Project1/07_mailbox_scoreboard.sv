/*
문제 5: Generator → Driver → Scoreboard (뼈대 없음)
이번엔 컴포넌트 3개 + mailbox 2개로 체인을 만들어요. solv4를 확장하는 거예요.

만들 것 (스펙만, 코드는 네가)
1. Transaction — rand bit [7:0] data 하나. (print는 원하는 대로)

2. Generator — 랜덤 트랜잭션 10개 만들어서 mailbox1에 넣기.

3. Driver — mailbox1에서 꺼내서 → mailbox2로 넘기기 (통과). 꺼낼 때 $display로 값 하나 찍기.

4. Scoreboard — mailbox2에서 꺼내서, data >= 128인 게 몇 개인지 세기 (MSB=1인 것). 10개 다 받은 뒤 count = N 출력.

5. top — mailbox 2개 만들고, gen·drv·sb를 각자 맞는 mailbox로 연결. fork로 셋 다 병렬 실행.

🆕 이번에 새로운 것 (개념만, 코드 X)
mailbox 2개 — mb1(gen→drv), mb2(drv→sb). top에서 둘 다 만들어 나눠줘요.
Driver는 mailbox 2개를 받아요 — 생성자 인자가 2개가 되겠죠 (in, out). (전에 배운 "인자 여러 개"!)
Scoreboard는 상태를 기억해요 — count를 프로퍼티로 두고 루프 돌며 누적. (클래스 레벨 변수 = 공용, 배운 거!)
✅ 자가 검증
Driver가 10줄 찍힘 (10개 흘러감)
Scoreboard가 마지막에 count = ? 찍힘
8비트 랜덤이라 data>=128(MSB=1)은 대략 절반 → 10개 중 4~6개쯤 나오면 정상
파일 & 실행
Project1/solv5.sv:

svrun ./Project1/solv5.sv
전부 네가 설계해봐요 — 클래스 4개, mailbox 2개, 연결, fork. 지금까지 배운 걸 다 쓰는 거예요:

컴포넌트가 mailbox 받기 (생성자)
function vs task
벨트 공유 (this.mb = mb)
상태 누적 (count 프로퍼티)
*/


class Transaction;
    rand bit [7:0]data;
    
    function void print();
        $display("data = %h", data);
    endfunction
endclass

class Generator;
    mailbox #(Transaction) mb1;
    function new(mailbox #(Transaction)mb1);
        this.mb1 = mb1;
    endfunction

    task run;
        begin
            $display("===========================");
            repeat(10)begin
                Transaction handle = new();
                if(handle.randomize() == 0)begin
                    $fatal(1, "error!");
                end
                mb1.put(handle);
                handle.print();   
            end
        end
    endtask
endclass

class Driver;
    mailbox #(Transaction) mb1;
    mailbox #(Transaction) mb2;

    function new(mailbox #(Transaction) mb1, mailbox #(Transaction)mb2);
        this.mb1 = mb1;
        this.mb2 = mb2;
    endfunction

    task run;
        begin
            $display("===========================");
            repeat(10)begin
                Transaction handle;
                mb1.get(handle);
                mb2.put(handle);
                handle.print();
            end
        end
    endtask
endclass

class Scoreboard;
    int count;
    mailbox #(Transaction) mb2;
    function new(mailbox #(Transaction)mb2);
        this.mb2 = mb2;
    endfunction

    task run;
        begin
            Transaction handle;
            repeat(10) begin
                mb2.get(handle);
                if(handle.data[7] == 1'b1)begin
                    count ++;
                end
            end
            $display("128을 넘어간 data는 %d", count);
        end
    endtask
endclass

module Top;
    mailbox #(Transaction) mb1 = new();
    mailbox #(Transaction) mb2 = new();
    Generator gen = new(mb1);
    Driver dri = new(mb1, mb2);
    Scoreboard scb = new(mb2);

    initial begin
        fork
            gen.run();
            dri.run();
            scb.run();
        join
    end
endmodule