/*
【1】 solv8 — mailbox/fork 워밍업 (흐름 제어)
맨 위: `timescale 1ns/1ps

만들 것 (코드는 당신이):

Transaction — rand bit [7:0] data;
Producer — mb 받고: 8개를 빠르게(delay 없이) 생성해서 put. 넣을 때마다 $display("[%0t] 생산 data=%h (벨트 %0d개)", $time, ..., mb.num());
Consumer — mb 받고: 느리게 소비 — get 하기 전에 #20;. 받을 때마다 시간이랑 값 출력.
Top — 칸 3개짜리 벨트: mailbox #(Transaction) mb = new(3); → producer·consumer 연결 → fork...join
🆕 이번 포인트: new(3)(칸 제한), mb.num()(벨트에 몇 개 있나)

✅ 관찰: 생산자가 순식간에 3개 채우고 멈춤 → 소비자가 20ns마다 하나씩 빼주면 → 생산자가 그때그때 하나씩 더 넣음. 벨트가 계속 3 근처. fork 덕에 데드락 없이 흐름 조절되는 걸 확인.

🔥 실험: new(3) → new(3) 그대로 두고 fork만 빼서 순차로 → 어제 배운 대로 데드락(생산자 3개 넣고 4개째서 멈춤, 소비자 시작 못 함). 5초 뒤 저절로 끝나거나 멈추면 그게 데드락이에요.
*/

`timescale 1ns/1ps
class Transaction;
    rand bit[7:0]data;

    function void print();
        $display("time: %0t || data: %h", $time, data);
    endfunction
endclass

class Producer;
    mailbox #(Transaction)mb;
    function new(mailbox #(Transaction)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(8)begin
                Transaction handle = new();
                if(handle.randomize() == 0)begin
                    $fatal(1,"ERROR");
                end
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
            repeat(8)begin
                Transaction handle;
                #20;
                mb.get(handle);
                handle.print();
            end
        end
    endtask
endclass

module Top;
    mailbox #(Transaction)mb = new(3);      //벨트 위에 올릴 수 있는 칸 3개 제한
    Producer pro = new(mb);
    Consumer con = new(mb);

    initial begin
        fork
            pro.run();
            con.run();
        join
    end
endmodule

/*
3으로 제한하면 생성자 세개 연속으로 나오고 그다음에 소비자 가져가고 다시 생산자올리고..
*/