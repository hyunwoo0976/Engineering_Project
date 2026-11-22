/*
목표: solv10 확장 — 자식을 2종류(Read/Write) 로. 한 벨트에 읽기·쓰기 트랜잭션을 섞어 흘리고, 소비자가 다형적으로 처리. (실무의 read/write 트랜잭션 흐름 느낌)

만들 것
① 설계도 3개

BaseTr (부모): 8비트 랜덤 addr 하나. print는 virtual, addr=.. 출력.
ReadTr (자식, BaseTr 상속): print 재정의 — 부모 print 부르고(super) 뒤에 → READ 붙이기. (새 필드 없이 라벨만)
WriteTr (자식, BaseTr 상속): 8비트 랜덤 wdata 추가. print 재정의 — 부모 print 부르고 → WRITE wdata=.. 붙이기.
② Generator (생산자)

생성자로 mailbox 받음.
6개 만드는데 짝수번 = ReadTr, 홀수번 = WriteTr.
각각 랜덤화 후 벨트에 put.
③ Consumer (소비자)

같은 mailbox 받음.
6개 get해서 각각 print.
④ Top

벨트 타입은 mailbox #(BaseTr).
gen·con 만들어 같은 벨트 연결, fork로 동시 실행.
🔑 힌트 (방향만, 코드 X)
벨트가 BaseTr 타입 → Read도 Write도 둘 다 실려요 (둘 다 is-a BaseTr).
자식 물건은 자식 타입 리모콘으로 new.
WriteTr을 randomize하면 addr(부모 것)랑 wdata(자기 것) 둘 다 랜덤돼요.
Consumer는 BaseTr 리모콘으로 받아도 virtual이 알아서 Read/Write 구분해 찍어요.
✅ 자가 검증
Read / Write 번갈아 6개.
Read → addr=.. → READ
Write → addr=.. → WRITE wdata=..
print는 Consumer에만! (solv10 교훈 — 생산자엔 print 넣지 말기, 안 그럼 두 번 나옴)
svrun ./systemverilog/Project1/solv11.sv
*/

class BaseTr;
    rand bit[7:0]addr;

    virtual function void print();
        $display("addr = %h", addr);
    endfunction
endclass

class ReadTr extends BaseTr;
    function void print();
        super.print();
        $display("[READ]");
    endfunction
endclass

class WriteTr extends BaseTr;
    rand bit[7:0]data;

    function void print();
        super.print();
        $display("      -> data: %h", data);
    endfunction
endclass

class Generator;
    mailbox #(BaseTr)mb;

    function new(mailbox #(BaseTr)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            for(int i =0; i<6; i++)begin
                if(i%2 == 0)begin
                    ReadTr red;
                    red = new();
                    if(red.randomize() == 0)begin
                        $fatal(1, "ERROR");
                    end
                    mb.put(red);
                end
                else begin
                    WriteTr wri;
                    wri = new();
                    if(wri.randomize() == 0)begin
                        $fatal(1, "ERROR");
                    end
                    mb.put(wri);
                end
            end
        end
    endtask
endclass

class Consumer;
    mailbox #(BaseTr)mb;
    
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
    mailbox #(BaseTr)mb = new();
    Generator gen = new(mb);
    Consumer con = new(mb);

    initial begin
        fork
            gen.run();
            con.run();
        join
    end
endmodule



            