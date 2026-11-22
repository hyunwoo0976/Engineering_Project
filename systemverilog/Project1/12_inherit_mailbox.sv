/*
📋 solv10 작업지시서
목표: 상속 + mailbox 결합. 한 벨트에 부모·자식 물건을 섞어 흘려보내고, 소비자가 다형적으로 처리.

만들 것
① 물건 설계도 2개

BaseTr (부모): 8비트 랜덤 data 하나. print 함수는 virtual로, [기본] data=.. 출력.
ExtTr (자식): BaseTr 물려받음. 8비트 랜덤 tag 추가. print를 재정의 — 부모 print 먼저 부르고(super) 그 뒤에 tag 출력.
② Generator (생산자)

생성자로 mailbox 하나 받음.
물건 6개 만드는데 부모·자식 번갈아 (짝수번 = 부모, 홀수번 = 자식).
각각 랜덤화한 뒤 벨트에 put.
③ Consumer (소비자)

생성자로 같은 mailbox 받음.
6개 get해서 각각 print.
④ Top

벨트 타입은 mailbox #(BaseTr) (부모 타입!).
생산자·소비자 만들어서 같은 벨트에 연결.
fork로 둘 다 동시 실행.
🔑 개념 힌트 (코드 아님, 방향만)
벨트가 부모 타입이라 자식 물건도 실려요 (자식 is-a 부모).
자식 물건을 만들 땐 자식 타입 리모콘으로 new 해야 해요 (부모 리모콘으로 new하면 부모 물건만 나옴 — 어제 배운 것).
소비자는 부모 타입 리모콘으로 받아도, virtual 덕분에 실제 물건 종류대로 print돼요.
✅ 자가 검증
짝수번(부모) → 한 줄(data), 홀수번(자식) → 두 줄(data+tag), 번갈아 나옴.
총 6개 다 흐름.
*/

class BaseTr;
    rand bit [7:0]data;

    virtual function void print();
        $display("[기본] data = %h", data);
    endfunction
endclass

class ExtTr extends BaseTr;
    rand bit[7:0]tag;

    function void print();
        super.print();
        $display("      (+) tag: %h", tag);
    endfunction
endclass

class Generator;
    mailbox #(BaseTr) mb;

    function new(mailbox #(BaseTr)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            for(int i = 0; i < 6; i++)begin
                if(i % 2 == 0)begin
                    BaseTr b_handle;
                    b_handle = new();
                    if(b_handle.randomize() == 0)begin
                        $fatal(1, "adult_ERROR");
                    end
                    mb.put(b_handle);
                end

                else begin
                    ExtTr e_handle;
                    e_handle = new();
                    if(e_handle.randomize() == 0)begin
                        $fatal(1,"ERROR");
                    end
                    mb.put(e_handle);
                end
            end
        end
    endtask
endclass

class Consumer;
    mailbox #(BaseTr) mb;

    function new(mailbox #(BaseTr)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(6)begin
                BaseTr handle;
                mb.get(handle);
                handle.print();
            end
        end
    endtask
endclass

module Top;
    mailbox #(BaseTr)mb =new();

    Generator gen = new(mb);
    Consumer con = new(mb);

    initial begin
        fork
            gen.run();
            con.run();
        join
    end
endmodule