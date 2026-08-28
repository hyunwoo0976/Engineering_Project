class Packet;
    int id;
    int data;

    function new(int id, int data);
        this.id = id;
        this.data = data;
    endfunction
endclass


class Producer;
    mailbox #(Packet)out_mb;

    function new(mailbox #(Packet)mb_A);
        out_mb = mb_A;
    endfunction

    task run;
        begin
            for(int i = 1; i<=5; i++)begin
                Packet handle = new(i,i);
                out_mb.put(handle);
            end
        end
    endtask
endclass

class Double;
    mailbox #(Packet) in_dou;
    mailbox #(Packet) out_dou;

    function new(mailbox #(Packet) mb_A, mailbox #(Packet)mb_B);
        in_dou = mb_A;
        out_dou = mb_B;
    endfunction

    task run;
        begin
            repeat(5)begin
                Packet handle;
                in_dou.get(handle);
                handle.data = handle.data*2;
                out_dou.put(handle);
            end
        end
    endtask
endclass

class Scoreboard;
    mailbox #(Packet)in_scr;
    int PASS = 0;
    int FAIL = 0;

    function new(mailbox #(Packet)mb_B);
        in_scr = mb_B;
    endfunction

    task run;
        begin
            repeat(5)begin
                Packet handle;
                in_scr.get(handle);
                if(handle.data == handle.id*2)begin
                    PASS++;
                end
                else begin
                    FAIL++;
                end
                $display("id = %0d | data = %0d", handle.id, handle.data);
            end
            $display("PASS: %0d || FAIL: %0d", PASS, FAIL);
        end
    endtask
endclass

module Top;
    mailbox #(Packet) mb_A = new();
    mailbox #(Packet) mb_B = new();

    Producer pro = new(mb_A);
    Double dou = new(mb_A, mb_B);
    Scoreboard src = new(mb_B);

    initial begin
        fork
            pro.run();
            dou.run();
            src.run();
        join
    end
endmodule