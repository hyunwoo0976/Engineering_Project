class Transaction;
    rand bit [7:0] data;
    function void print();
        $display("data = %h", data);
    endfunction
endclass

class Generator;
    mailbox #(Transaction) mb;     // 파이프 핸들 (내 것)

    function new (mailbox #(Transaction) mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(5)begin
                Transaction handle;
                handle = new();
                if(handle.randomize() == 32'b0)begin
                    $fatal(1, "에러");
                end
                mb.put(handle);
                handle.print();
            end
        end
    endtask
    // TODO(1): 생성자 — 밖에서 파이프 받아서 this.mb에 저장
    // TODO(2): task run() — repeat(5): t=new(); randomize 체크; mb.put(t)
endclass

class Driver;
    mailbox #(Transaction) mb;

    function new(mailbox #(Transaction) mb);
        this.mb = mb;
    endfunction

    task run;
        repeat(5)begin
            Transaction handle;
            mb.get(handle);
            handle.print();
        end
    endtask
    // TODO(3): 생성자 — 파이프 받기 (Generator랑 똑같이)
    // TODO(4): task run() — repeat(5): mb.get(t); t.print();
endclass

module top;
    mailbox #(Transaction) mb = new();
    Generator gen = new(mb);
    Driver dri = new(mb);
    // TODO(5): Generator gen = new(mb);   // 같은 파이프를 gen에 줌
    // TODO(6): Driver drv = new(mb);      // 같은 파이프를 drv에 줌 → 연결!
    initial begin
        fork
            gen.run();
            dri.run();
        join
        // TODO(7): fork  gen.run();  drv.run();  join
        $finish;
    end
endmodule