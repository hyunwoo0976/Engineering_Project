/*Transaction — 필드 2개:
rand bit [7:0] data; (입력, 랜덤)
bit [7:0] result; (출력 자리, rand 아님 — 나중에 채워짐)
print는 data랑 result 둘 다 찍기
Generator — 랜덤 10개 만들어(→ data만 랜덤) mb1에 put. (result는 그대로 0)
Driver — 이번엔 "DUT(가공하는 하드웨어)" 역할:
mb1에서 get
result = data + 1 로 계산해서 채우기
mb2에 put + print
Scoreboard — "검사관" 역할:
mb2에서 get
자기가 직접 기댓값 계산: expected = data + 1
result(Driver가 준 답)하고 expected(내가 계산한 답)를 비교:
같으면 → pass_cnt++
다르면 → err_cnt++ 하고 $display로 어긋난 값 찍기
10개 다 본 뒤 → pass_cnt, err_cnt 출력
err_cnt == 0 이면 "ALL PASS ✅", 아니면 "FAIL ❌" 출력
top — solv5랑 똑같이 배선 + fork
🆕 이번 포인트:

Transaction이 필드 여러 개(입력 data + 출력 result) 를 벨트로 실어 나름
스코어보드가 답을 직접 계산해서 비교 ← 이게 검증의 심장이에요
int pass_cnt = 0; int err_cnt = 0; (아까 배운 초기화!)
왜 이게 중요하냐: 당신 README에 이미 써 있어요 — "기댓값은 스펙에서 유도하지, DUT에서 베끼지 않는다." Scoreboard가 Driver 코드를 안 보고 스스로 data+1을 계산하는 게 정확히 그거예요. Driver가 몰래 틀려도 Scoreboard가 잡아내죠.

✅ 자가 검증:

Driver가 10줄 찍힘
err_cnt = 0, "ALL PASS" 뜨면 정상 (Driver랑 Scoreboard가 똑같이 +1 하니까 다 맞아야 함)
🔥 보너스 (이거 꼭 해봐요):
정상 확인한 뒤, Driver만 result = data + 2 로 몰래 고쳐서 다시 돌려봐요. Scoreboard는 그대로 +1로 검사하니까 → 전부 FAIL이 떠야 해요. 이게 뜨면 "아, 내 검사기가 진짜 버그를 잡는구나"를 눈으로 보는 거예요. 검증기가 버그를 못 잡으면 검증기가 아니에요.

svrun ./systemverilog/Project1/solv6.sv
*/


class Transaction;
    rand bit[7:0]data;
    bit [7:0]result;

    function void print();
        $display ("데이터: %h | 결과 값: %h", data, result);
    endfunction
endclass

class Generator;
    mailbox #(Transaction)mb1;
    function new(mailbox #(Transaction)mb1);
        this.mb1 = mb1;
    endfunction

    task run;
        begin
            repeat(10)begin
                Transaction handle = new();
                if(handle.randomize() == 0)begin
                    $fatal(1, "error!");
                end
                mb1.put(handle);
            end
        end
    endtask
endclass

class Driver;
    mailbox #(Transaction)mb1;
    mailbox #(Transaction)mb2;
    
    function new(mailbox #(Transaction)mb1, mailbox #(Transaction)mb2);
        this.mb1 = mb1;
        this.mb2 = mb2;
    endfunction

    task run;
        begin
            repeat(10)begin
                Transaction handle;
                mb1.get(handle);
                handle.result = handle.data + 1;
                handle.print();
                mb2.put(handle);
            end
        end
    endtask
endclass

class Scoreboard;
    int pass_cnt = 0;
    int err_cnt = 0;
    bit [7:0]expected;
    mailbox #(Transaction)mb2;

    function new(mailbox #(Transaction)mb2);
        this.mb2 = mb2;
    endfunction

    task run;
        begin
            repeat(10)begin
                Transaction handle;
                mb2.get(handle);
                expected = handle.data + 1;
                handle.print();
                if(handle.result == expected)begin
                    pass_cnt ++;
                    $display("PASS");
                end
                else begin
                    err_cnt ++;
                    $display("FAIL");
                end
            end
            $display("같은 횟수는 %0d, 다른 횟수는 %0d입니다", pass_cnt, err_cnt);
        end
    endtask
endclass

module Top;
    mailbox #(Transaction)mb1 = new();
    mailbox #(Transaction)mb2 = new();

    Generator gen = new(mb1);
    Driver dri = new(mb1, mb2);
    Scoreboard src = new(mb2);

    initial begin
        fork
            gen.run();
            dri.run();
            src.run();
        join
    end
endmodule




