/*
📋 solv12 작업지시서
목표: solv11이랑 똑같은 구조, 자식만 3종류로. (하나의 base에서 여러 자식이 나와 한 벨트로 흐르는 게 UVM의 실제 모습)

만들 것
① 물건 4개 (mailbox 없음! 필드 + print만)

BaseTr (부모): 8비트 랜덤 id. print는 virtual, id=.. 출력.
CmdTr (자식): 8비트 랜덤 cmd 추가. print 재정의 → super + [CMD] cmd=..
DataTr (자식): 8비트 랜덤 payload 추가. print 재정의 → super + [DATA] payload=..
RespTr (자식): 8비트 랜덤 code 추가. print 재정의 → super + [RESP] code=..
② Generator (사람): mailbox 받고, 9개 만드는데 i % 3으로 3종류 번갈아 (0→Cmd, 1→Data, 2→Resp). 각각 new + 랜덤 + put.

③ Consumer (사람): 같은 mailbox 받고, 9개 get해서 print.

④ Top: mailbox #(BaseTr), gen·con 연결, fork.

✅ 스스로 점검 체크리스트 (자꾸 걸리던 것들!)
짜고 나서 이 4개 꼭 확인해요 — 지금까지 매번 여기서 막혔어요:

미완료
물건 = 필드 + print만 (mailbox·run 없음). 사람 = mailbox + run. 안 섞였나?
미완료
자식 물건 만들 때 자식 타입으로 new 했나? (CmdTr c = new(); — 리모콘만 선언하면 null!)
미완료
여러 개니까 반복문 넣었나? (Generator for 9번, Consumer repeat(9))
미완료
print는 Consumer에만 넣었나? (Generator엔 X)
자가 검증
Cmd → Data → Resp 순서로 돌아가며 9개.
예: id=.. [CMD] cmd=.. / id=.. [DATA] payload=.. / id=.. [RESP] code=..
svrun ./systemverilog/Project1/solv12.sv
*/

class BaseTr;
    rand bit[7:0]id;

    virtual function void print();
        $display("    <<id = %h>>     ", id);
    endfunction 
endclass

class CmdTr extends BaseTr;
    rand bit[7:0]cmd;

    function void print();
        super.print();
        $display("L [CMD] cmd = %h", cmd);
    endfunction
endclass

class DataTr extends BaseTr;
    rand bit [7:0]payload;

    function void print();
        super.print();
        $display("L [DATA] payload = %h", payload);
    endfunction
endclass

class RespTr extends BaseTr;
    rand bit [7:0]code;

    function void print();
        super.print();
        $display("L [RESP] code = %h", code);
    endfunction
endclass

class Generator;
    mailbox #(BaseTr)mb;

    function new(mailbox #(BaseTr)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            for(int i=0; i<9; i++)begin
                if(i%3==0)begin
                    CmdTr c_handle;
                    c_handle =  new();
                    if(c_handle.randomize() == 0)begin
                        $fatal(1,"CMD_ERROR");
                    end
                    mb.put(c_handle);
                end
                else if(i%3==1)begin
                    DataTr d_handle;
                    d_handle = new();
                    if(d_handle.randomize() == 0)begin
                        $fatal(1, "DATA_ERROR");
                    end
                    mb.put(d_handle);
                end
                else begin
                    RespTr r_handle;
                    r_handle = new();
                    if(r_handle.randomize() == 0)begin
                        $fatal(1, "RESP_ERROR");
                    end
                    mb.put(r_handle);
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
            repeat(9)begin
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
